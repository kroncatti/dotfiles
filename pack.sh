
echo 'Installing software using brew'
brew bundle

echo 'Setting up ZSH'
cp $PWD/.zshrc $HOME/.zshrc

echo 'Setting up Hammerspoon'
mkdir -p $HOME/.hammerspoon
ln -sf $PWD/hammerspoon/init.lua $HOME/.hammerspoon/init.lua
echo 'Remember: grant Hammerspoon Accessibility permission (System Settings > Privacy & Security > Accessibility)'
