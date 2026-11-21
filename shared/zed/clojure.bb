#!/usr/bin/env bb
;; Clojure helpers for Zed, run by the tasks in shared/zed/tasks.json.
;; ~/.config/zed/clojure.bb is a symlink to this file.
;;
;; Zed has no nREPL client and no paredit, so this script fills the gap:
;;   REPL:     bb clojure.bb eval FILE ROW COL [SELECTION]   selection (or $ZED_SELECTED_TEXT), else the top-level form
;;             bb clojure.bb eval-before FILE ROW COL        the form that ends right before the cursor
;;             bb clojure.bb load-file FILE                  the whole file
;;             bb clojure.bb start-repl DIR                  start an nREPL server for the project in DIR
;;   Paredit:  bb clojure.bb <op> FILE ROW COL               edits FILE in place; Zed reloads it
;;             <op> is slurp-forward, barf-forward, slurp-backward, barf-backward, raise or splice
;; ROW and COL are 1-based, as Zed's $ZED_ROW and $ZED_COLUMN are.

(ns zed-clojure
  (:require [babashka.fs :as fs]
            [babashka.process :as p]
            [bencode.core :as b]
            [clojure.string :as str]
            [rewrite-clj.paredit :as pe]
            [rewrite-clj.zip :as z])
  (:import (java.io PushbackInputStream)
           (java.net Socket)))

(defn die [& msg]
  (binding [*out* *err*] (println (str/join " " msg)))
  (System/exit 1))

;; ---------------------------------------------------------------------------
;; Locating forms

;; positioned on the first top-level form (nil for an empty file)
(defn zloc [s] (z/of-string s {:track-position? true}))

(defn cursor-pos
  "Zed's cursor sits between characters; ROW/COL name the character after it."
  [row col] [(parse-long (str row)) (parse-long (str col))])

(defn pos< [[r1 c1] [r2 c2]] (or (< r1 r2) (and (= r1 r2) (< c1 c2))))
(defn pos<= [a b] (not (pos< b a)))

(defn covers?
  "True if the cursor at pos is strictly inside loc's brackets (after the opener, up to the closer)."
  [loc pos]
  (let [[start end] (z/position-span loc)]
    (and (pos< start pos) (pos< pos end))))

(defn top-level-at
  "The top-level form containing pos, or the one ending right before it."
  [root pos]
  (let [forms (->> (iterate z/right root) (take-while some?))]
    (or (some #(let [[s e] (z/position-span %)] (when (and (pos<= s pos) (pos< pos e)) %)) forms)
        (last (filter #(pos<= (second (z/position-span %)) pos) forms)))))

(defn form-before
  "The innermost form whose end is exactly at pos (like Cursive's 'send form before caret')."
  [root pos]
  (->> (iterate z/next root)
       (take-while (complement z/end?))
       (filter #(= (second (z/position-span %)) pos))
       first))

(defn enclosing-seq
  "The innermost list/vector/map/set whose brackets contain pos."
  [root pos]
  (->> (iterate z/next root)
       (take-while (complement z/end?))
       (filter #(and (#{:list :vector :map :set :fn} (z/tag %)) (covers? % pos)))
       last))

(defn file-ns [src]
  (try
    (let [first-form (zloc src)]
      (loop [loc first-form]
        (cond
          (nil? loc) nil
          (and (= :list (z/tag loc)) (= 'ns (some-> loc z/down z/sexpr)))
          (some-> loc z/down z/right z/sexpr str)
          :else (recur (z/right loc)))))
    (catch Exception _ nil)))

;; ---------------------------------------------------------------------------
;; nREPL client

(defn find-up [dir filename]
  (loop [d (fs/absolutize dir)]
    (when d
      (let [f (fs/path d filename)]
        (if (fs/exists? f) f (recur (fs/parent d)))))))

(defn nrepl-port [file]
  (if-let [f (find-up (fs/parent file) ".nrepl-port")]
    (parse-long (str/trim (slurp (str f))))
    (die "No .nrepl-port found above" (str file)
         "\nStart one with the 'clojure: start nREPL' task (or `clj -M:nREPL -m nrepl.cmdline`).")))

(defn bytes->str [x] (if (bytes? x) (String. ^bytes x "UTF-8") x))

(defn decode [m]
  (cond (map? m) (into {} (map (fn [[k v]] [(keyword (bytes->str k)) (decode v)])) m)
        (sequential? m) (mapv decode m)
        :else (bytes->str m)))

(defn connect [port]
  (try
    (let [s (Socket. "localhost" (int port))]
      {:socket s :in (PushbackInputStream. (.getInputStream s)) :out (.getOutputStream s)})
    (catch java.net.ConnectException _
      (die (str "Cannot connect to nREPL on port " port ". Is the REPL running? (stale .nrepl-port?)")))))

(defn send! [{:keys [out]} msg] (b/write-bencode out msg) (.flush out))
(def debug? (some? (System/getenv "ZED_CLJ_DEBUG")))

(defn recv! [{:keys [in]}]
  (let [m (decode (b/read-bencode in))]
    (when debug? (binding [*out* *err*] (prn (dissoc m :changed-namespaces))))
    m))

(defn request!
  "Send msg and return all replies with its id, up to and including the one with status done.
   Replies to other ids (cider-nrepl sends a few unsolicited ones) are skipped."
  [conn msg]
  (let [id (str (random-uuid))]
    (send! conn (assoc msg "id" id))
    (loop [acc []]
      (let [m (recv! conn)]
        (cond (not= id (:id m)) (recur acc)
              (some #{"done"} (:status m)) (conj acc m)
              :else (recur (conj acc m)))))))

(defn print-responses
  "Print out/err/value messages until :done. Returns true if there was no error."
  [conn id]
  (loop [ok true]
    (let [{:keys [out err value ex status] :as msg} (recv! conn)]
      (if (not= id (:id msg))
        (recur ok)
        (do
          (when out (print out) (flush))
          (when err (binding [*out* *err*] (print err) (flush)))
          (when value (println "=>" value))
          (when (some #{"namespace-not-found"} status)
            (binding [*out* *err*] (println "Namespace not found:" (:ns msg))))
          (let [ok (and ok (nil? ex) (not (some #{"error" "eval-error"} status)))]
            (if (some #{"done"} status)
              ok
              (recur ok))))))))

(defn nrepl-op!
  "Send one op and print its output. Returns true if it succeeded."
  [file msg]
  ;; No session is sent: nREPL replies to a session over the connection that created it, and each
  ;; run of this script is a new connection, so every op runs in a fresh session (*1 and *e don't carry over).
  (let [conn (connect (nrepl-port file))
        id (str (random-uuid))]
    (send! conn (assoc msg "id" id))
    (let [ok (print-responses conn id)]
      (.close ^Socket (:socket conn))
      ok)))

(defn eval-code! [file code {:keys [ns line column]}]
  (nrepl-op! file (cond-> {"op" "eval" "code" code "file" (str file)}
                    ns (assoc "ns" ns)
                    line (assoc "line" line)
                    column (assoc "column" column))))

(defn ns-loaded? [file ns]
  (let [conn (connect (nrepl-port file))
        v (some :value (request! conn {"op" "eval" "code" (str "(some? (find-ns '" ns "))")}))]
    (.close ^Socket (:socket conn))
    (= "true" v)))

(defn load-file!
  "nREPL's load-file op: creates the namespace if needed and keeps file/line info for stack traces."
  [file]
  (println (str "Loading " (fs/file-name file) "..."))
  (nrepl-op! file {"op" "load-file" "file" (slurp (str file))
                   "file-path" (str file) "file-name" (str (fs/file-name file))}))

(defn eval-form! [file code {:keys [line column]}]
  (let [src (slurp (str file))
        ns (file-ns src)]
    ;; Cursive evaluates in the file's namespace; load the file first if the REPL hasn't seen it.
    (when (and ns (not (ns-loaded? file ns)))
      (println (str "Namespace " ns " not loaded yet; loading the file first."))
      (load-file! file))
    (println (str (when ns (str ns " ")) "λ " (let [l (str/split-lines code)]
                                                  (str (first l) (when (next l) " …")))))
    (eval-code! file code {:ns ns :line line :column column})))

;; ---------------------------------------------------------------------------
;; Paredit: edit the file on disk; Zed reloads the (saved) buffer.

(defn inside
  "A loc pointing inside the innermost seq around pos, which the rewrite-clj paredit fns operate on.
   For an empty seq, returns the seq itself with :empty? so callers can handle it."
  [root pos]
  (when-let [s (enclosing-seq root pos)]
    (if-let [child (z/down s)]
      ;; the child nearest to the cursor, so the result matches the form the cursor is in
      (or (last (filter #(pos<= (first (z/position-span %)) pos)
                        (take-while some? (iterate z/right child))))
          child)
      (vary-meta s assoc ::empty? true))))

(defn slurp-into-empty
  "rewrite-clj can't slurp into an empty seq; do it by hand: () x  ->  (x)"
  [loc]
  (when-let [nxt (z/right loc)]
    (let [node (z/node nxt)]
      (-> loc (z/append-child node) z/right z/remove))))

(def ops
  {"slurp-forward"  (fn [loc] (if (::empty? (meta loc)) (slurp-into-empty loc) (pe/slurp-forward loc)))
   "barf-forward"   (fn [loc] (when-not (::empty? (meta loc)) (pe/barf-forward loc)))
   "slurp-backward" (fn [loc] (when-not (::empty? (meta loc)) (pe/slurp-backward loc)))
   "barf-backward"  (fn [loc] (when-not (::empty? (meta loc)) (pe/barf-backward loc)))
   ;; raise: replace the enclosing seq with the form under the cursor
   "raise"          (fn [loc] (when-not (::empty? (meta loc)) (pe/raise loc)))
   ;; splice: remove the brackets of the enclosing seq
   "splice"         (fn [loc] (if (::empty? (meta loc)) (z/remove loc) (pe/splice (z/up loc))))})

(defn paredit! [op file row col]
  (let [f (ops op)
        src (slurp (str file))
        root (zloc src)
        pos (cursor-pos row col)
        loc (or (inside root pos) (die "Cursor is not inside a form"))
        result (try (f loc) (catch Exception e (die op "failed:" (ex-message e))))]
    (when-not result (die op "is not possible here"))
    (let [out (z/root-string result)]
      (when (not= out src)
        ;; write to a temp file and move it over, so Zed never sees a half-written file
        (let [tmp (fs/create-temp-file {:dir (fs/parent file) :prefix ".zed-paredit-"})]
          (spit (str tmp) out)
          (fs/move tmp file {:replace-existing true :atomic-move true}))))))

;; ---------------------------------------------------------------------------
;; Starting an nREPL server

(def nrepl-version "1.3.1")
(def cider-version "0.52.1")

(defn start-repl! [dir]
  (let [dir (fs/absolutize dir)
        has #(fs/exists? (fs/path dir %))
        cmd (cond
              (has "deps.edn")
              ["clojure" "-Sdeps"
               (pr-str {:deps {'nrepl/nrepl {:mvn/version nrepl-version}
                               'cider/cider-nrepl {:mvn/version cider-version}}})
               (str "-M" (or (System/getenv "CLJ_ALIASES") ""))
               "-m" "nrepl.cmdline" "--middleware" "[cider.nrepl/cider-middleware]" "--interactive"]

              (has "project.clj")
              (if (fs/which "lein")
                ["lein" "update-in" ":plugins" "conj" (str "[cider/cider-nrepl \"" cider-version "\"]")
                 "--" "repl"]
                (die "project.clj found but `lein` is not installed (brew install leiningen)"))

              (has "bb.edn")
              ["bb" "nrepl-server"]

              :else
              ["clojure" "-Sdeps" (pr-str {:deps {'nrepl/nrepl {:mvn/version nrepl-version}}})
               "-M" "-m" "nrepl.cmdline" "--interactive"])]
    (println "Starting:" (str/join " " cmd))
    (when (has "bb.edn") (println "(babashka writes no .nrepl-port; it listens on 1667)"))
    ;; inherit stdin/stdout so the task terminal is also an interactive REPL on the same server
    (apply p/shell {:dir (str dir) :continue true} cmd)))

;; ---------------------------------------------------------------------------

(defn -main [[cmd & args]]
  (case cmd
    "eval" (let [[file row col sel] args
                 ;; Zed exports task variables as env vars; reading the selection from there avoids shell quoting
                 sel (or sel (System/getenv "ZED_SELECTED_TEXT"))
                 file (fs/absolutize file)]
             (if-not (str/blank? sel)
               (eval-form! file sel {})
               (let [pos (cursor-pos row col)
                     form (or (top-level-at (zloc (slurp (str file))) pos) (die "No form at cursor"))
                     [l c] (first (z/position-span form))]
                 (eval-form! file (z/string form) {:line l :column c}))))
    "eval-before" (let [[file row col] args
                        file (fs/absolutize file)
                        form (or (form-before (zloc (slurp (str file))) (cursor-pos row col))
                                 (die "No form ends right before the cursor"))
                        [l c] (first (z/position-span form))]
                    (eval-form! file (z/string form) {:line l :column c}))
    "load-file" (load-file! (fs/absolutize (first args)))
    "start-repl" (start-repl! (or (first args) "."))
    (if (ops cmd)
      (let [[file row col] args] (paredit! cmd (fs/absolutize file) row col))
      (die "Unknown command:" (str cmd) "\nSee the header of this file for usage."))))

(when (= *file* (System/getProperty "babashka.file"))
  (when (false? (-main *command-line-args*))
    (System/exit 1)))
