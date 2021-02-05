# Install Vundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# Compile YCM
brew remove vim
brew cleanup
brew install vim
brew install cmake python mono go nodejs
cd ~/.vim/bundle/YouCompleteMe
python3 install.py --all