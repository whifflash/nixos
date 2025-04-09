#!/usr/bin/env bash


if tmux info &> /dev/null; then # check if server is running
	# has-session: Report an error and exit with 1 if the specified session does not exist.  If it does exist, exit with 0.
	if [ $(tmux has-session -t scratchpad) ]; then
		# TERM=screen-256color-bce tmux new-session -s scratchpad
		# echo 'session already there' > /tmp/reattach
		tmux new-session -s scratchpad # creates a new session
	else
		# echo 'starting new session, session did not yet exist' > /tmp/reattach
		# TERM=screen-256color-bce tmux new-session -s scratchpad || TERM=screen-256color-bce tmux attach-session -t scratchpad
		tmux new-session -s scratchpad || tmux attach-session -t scratchpad
	fi
else
	# echo 'starting new session, tmux server was not up' > /tmp/reattach
	# TERM=screen-256color-bce tmux new-session -s scratchpad || TERM=screen-256color-bce tmux attach-session -t scratchpad
	tmux new-session -s scratchpad || tmux attach-session -t scratchpad
fi

