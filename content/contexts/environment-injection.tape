# Renders content/assets/environment-injection.gif.
# Regenerate: vhs content/contexts/environment-injection.tape
#
# Shows environment injection for real: KUBECONFIG is unset outside a
# trusted project, and populated automatically on the next prompt after
# cd-ing into one. No windsor command is run by hand.
Output ../assets/environment-injection.gif

Set Shell "zsh"
Set FontSize 20
Set Width 1000
Set Height 320
Set Padding 20
Set WindowBar Colorful
Set Theme "Dracula"
Set TypingSpeed 45ms

# Self-contained: builds its own throwaway trusted project under /tmp
# so this reproduces with no manual setup, in CI or anywhere else.
# The hook is normally installed once in ~/.zshrc (see "Set it up
# once" above); VHS runs a clean shell for reproducibility, so eval it
# here instead, invisibly, to reproduce that already-installed state.
Hide
Type `rm -rf /tmp/windsor-demo && mkdir -p /tmp/windsor-demo && cd /tmp/windsor-demo && git init -q && windsor init >/dev/null 2>&1 && cd /tmp`
Enter
Sleep 3s
Type `eval "$(windsor hook zsh)"`
Enter
Sleep 500ms
Type `clear`
Enter
Sleep 300ms
Show

Sleep 1s
Type `cd /tmp`
Enter
Sleep 500ms
Type `echo $KUBECONFIG`
Enter
Sleep 1.5s

Type `cd /tmp/windsor-demo`
Enter
Sleep 500ms
Type `echo $KUBECONFIG`
Enter
Sleep 2.5s
