(require 'ruby-mode)
(require 'inf-ruby)
(require 'json)

(defvar burdock-mode-map
  (make-sparse-keymap)
  "TODO")


(define-minor-mode burdock-mode
  "TODO"
  :lighter " Burdock"
  :keymap burdock-mode-map)


(defcustom burdock-ruby-source-directory
  "/Users/noprompt/git/noprompt/rhubarb-mode/ruby/"
  "The Burdock Ruby source directory."
  :type '(file :must-match t)
  :group 'burdock-mode)


;; ---------------------------------------------------------------------
;; burdock-repl

(defun burdock-repl-clear-buffer ()
  "Clears the `inf-ruby-buffer' if it exists."
  (interactive)
  (when (bufferp (get-buffer inf-ruby-buffer))
    (with-current-buffer inf-ruby-buffer
      (let ((comint-buffer-maximum-size 0))
	(comint-truncate-buffer))))) 

(defun burdock-repl-send-lines (lines)
  "Insert each line in `lines' into the `inf-ruby-buffer' if it
exists."
  (when (bufferp (get-buffer inf-ruby-buffer))
    (let ((buff (current-buffer)))
      ;; HACK: I have no idea why this is necessary but without it the
      ;; REPL breaks when the point in the `inf-ruby-buffer' is anywhere
      ;; other than `point-max'.
      (switch-to-buffer-other-frame inf-ruby-buffer)
      (goto-char (point-max))
      (switch-to-buffer-other-frame buff)
      (with-current-buffer inf-ruby-buffer
	(dolist (line lines)
	  ;; HACK: This ensures that each line of input is preceded by the
	  ;; prompt in IRB. For Pry `Pry.config.auto_indent = false' can
	  ;; be specified in the ~/.pryrc to preven issues with the
	  ;; prompt.
	  (insert line)
	  (sleep-for 0 5)
	  (call-interactively (key-binding (kbd "<RET>"))))))))


;; ---------------------------------------------------------------------
;; burdock-client

(defvar burdock-callback-table
  (make-hash-table :test 'equal))

;; SEE: http://nullprogram.com/blog/2010/05/11/
(defun burdock-uuid-create ()
  "Return a newly generated UUID. This uses a simple hashing of
variable data."
  (let ((s (md5 (format "%s%s%s%s%s%s%s%s%s%s"
                        (user-uid)
                        (emacs-pid)
                        (system-name)
                        (user-full-name)
                        user-mail-address
                        (current-time)
                        (emacs-uptime)
                        (garbage-collect)
                        (random)
                        (recent-keys)))))
    (format "%s-%s-3%s-%s-%s"
            (substring s 0 8)
            (substring s 8 12)
            (substring s 13 16)
            (substring s 16 20)
            (substring s 20 32))))

(defun burdock-send-request (burdock-process request-data &optional callback)
  (let* ((id (burdock-uuid-create))
	 (request-data-with-id (cons `(id . ,id) request-data)))
    (puthash id (or callback 'identity) burdock-callback-table)
    (process-send-string burdock-process (json-encode request-data-with-id))
    (process-send-string burdock-process "\n")))

(defun burdock-receive-response (burdock-process response-string)
  (let* ((response-data (json-read-from-string response-string))
	 (id (cdr (assoc 'id response-data)))
	 (callback (gethash id burdock-callback-table 'identity)))
    (funcall callback response-data)
    (remhash id burdock-callback-table)))

(defun burdock-error-response-p (response-data)
  (assoc 'error response-data))

(defun burdock-get-parameter (key response-data)
  (cdr (assoc key (cdr (assoc 'params response-data)))))

;; ---------------------------------------------------------------------
;; burdock-process

(defconst burdock-process nil
  "The Burdock ruby process.")

(defvar burdock-process-filter
  (lambda (process response-string)
    (funcall 'burdock-receive-response process response-string)))

(defun burdock-setup ()
  (let* ((default-directory burdock-ruby-source-directory)
	 (bundler-buffer (get-buffer-create "*bundler*"))
	 (exit-code (shell-command "bundle install --path=vendor"
				   bundler-buffer
				   bundler-buffer)))
    (kill-buffer bundler-buffer)))

(defun burdock-initialize-process ()
  (when (or (not burdock-process)
	    (not (process-live-p burdock-process)))
    (let* ((process-connection-type nil) ;; Use a pipe.
	   (process (let ((default-directory burdock-ruby-source-directory))
		      (start-process "*burdock*" nil
				     "bundle" "exec" "bin/burdock"))))
      (set-process-filter process burdock-process-filter)
      (setq burdock-process process))))

(defun burdock-start ()
  "Starts the `burdock-process'."
  (interactive)
  (burdock-initialize-process))

(defun burdock-stop ()
  "Stops the `burdock-process' if it is live."
  (interactive)
  (when (process-live-p burdock-process)
    (kill-process burdock-process)
    (setq-local burdock-process nil)))

(defun burdock-restart ()
  "Restarts the `burdock-process'."
  (interactive)
  (burdock-stop)
  (burdock-start))

(defun burdock-status ()
  (interactive)
  (message "%s" (process-status burdock-process)))


;; ---------------------------------------------------------------------
;; burdock-process-interaction

(defun burdock-emacs-point-to-burdock-point (emacs-point)
  "Given an Emacs point, return a point value compatible with the
Burdock server."
  (- emacs-point 1))

(defun burdock-emacs-point-from-burdock-point (burdock-point)
  "Given an point value from the Burdock server, convert it to a point
value compatible for Emacs."
  (+ burdock-point 1))

(defun burdock-base-parameters ()
  (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
	 (burdock-point (burdock-emacs-point-to-burdock-point (point)))
	 (line-number (line-number-at-pos))
	 (column-number (current-column)))
    `((column . ,column-number)
      (line-number . ,line-number)
      (point . ,burdock-point)
      (source . ,source))))

(defun burdock-request (method &optional parameters)
  (let ((params (append parameters (burdock-base-parameters))))
    `((method . ,method)
      (params . ,(burdock-base-parameters)))))

(defun burdock-goto-start-point (response-data)
  (if (burdock-error-response-p response-data)
      nil
    (let* ((response-params (cdr (assoc 'params response-data)))
	   (start-point (cdr (assoc 'start_point response-params))))
      (if start-point
	  (let ((start-point (burdock-emacs-point-from-burdock-point start-point)))
	    (goto-char start-point))
	nil))))

(defun burdock-evaluate-source (response-data)
  (if (burdock-error-response-p response-data)
      nil
    (let* ((response-params (cdr (assoc 'params response-data)))
	   (source (cdr (assoc 'source response-params))))
      (burdock-repl-send-lines (split-string source "\n")))))

(defun burdock-zip-left ()
  (interactive)
  (let* ((request (burdock-request "burdock/zip-left")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-right ()
  (interactive)
  (let* ((request (burdock-request "burdock/zip-right")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-up ()
  (interactive)
  (let* ((request (burdock-request "burdock/zip-up")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-down ()
  (interactive)
  (let* ((request (burdock-request "burdock/zip-down")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-evaluate-scope-at-point ()
  (interactive)
  (let* ((request (burdock-request "burdock/scope-at-line")))
    (burdock-send-request burdock-process request 'burdock-evaluate-source)))

(defun burdock-evaluate-expression-at-point ()
  (interactive)
  (let* ((request (burdock-request "burdock/expression-at-point")))
    (burdock-send-request burdock-process request 'burdock-evaluate-source)))

(defun burdock-structured-wrap (left-delimiter right-delimiter &optional post-hook)
  (lexical-let ((request (burdock-request "burdock/expression-at-point"))
		(left-delimiter left-delimiter)
		(right-delimiter right-delimiter)
		(post-hook post-hook))
    (burdock-send-request burdock-process request
			  (lambda (response-data)
			    (if (burdock-error-response-p response-data)
				nil
			      (let ((start-point (burdock-get-parameter 'start_point response-data))
				    (end-point (burdock-get-parameter 'end_point response-data)))
				(if (and start-point
					 end-point)
				    (let ((start-point (burdock-emacs-point-from-burdock-point start-point))
					  (end-point (burdock-emacs-point-from-burdock-point end-point)))
				      (save-excursion
					(goto-char end-point)
					(insert right-delimiter)
					(goto-char start-point)
					(insert left-delimiter))
				      (when post-hook
					;; This may not be robust
					;; enough depending on the the
					;; delimiters used.
					(let ((start-point* (save-excursion
							      (search-backward left-delimiter)
							      (point)))
					      (end-point* (save-excursion
							    (search-forward right-delimiter)
							    (point)))))
					(funcall post-hook start-point* end-point*)))
				  nil))))))) 

(defun burdock-structured-wrap-round ()
  (interactive)
  (burdock-structured-wrap "(" ")"))

(defun burdock-structured-wrap-square ()
  (interactive)
  (burdock-structured-wrap "[" "]"))

(defun burdock-structured-wrap-curly ()
  (interactive)
  (burdock-structured-wrap "{" "}"))

(defun burdock-structured-wrap-double-quote ()
  (interactive)
  (burdock-structured-wrap "\"" "\""))

(defun burdock-structured-wrap-single-quote ()
  (interactive)
  (burdock-structured-wrap "'" "'"))

(defun burdock-structured-wrap-lambda ()
  (interactive)
  (burdock-structured-wrap "lambda do\n" "\nend"
			   (lambda (start-point end-point)
			     (indent-region start-point end-point))))

(defun burdock-structured-wrap-lambda-call ()
  (interactive)
  (burdock-structured-wrap "lambda do\n" "\nend.call"
			   (lambda (start-point end-point)
			     (indent-region start-point end-point))))

(provide 'burdock-mode)

(defun ~/define-evil-keys-for-burdock-mode ()
  (interactive)
  (define-key evil-normal-state-local-map ",e" 'burdock-evaluate-scope-at-point)
  (define-key evil-normal-state-local-map "W(" 'burdock-structured-wrap-round)
  (define-key evil-normal-state-local-map "W[" 'burdock-structured-wrap-square)
  (define-key evil-normal-state-local-map "W{" 'burdock-structured-wrap-curly)
  (define-key evil-normal-state-local-map "W\"" 'burdock-structured-wrap-double-quote)
  (define-key evil-normal-state-local-map "W'" 'burdock-structured-wrap-single-quote)
  (define-key evil-normal-state-local-map "Wl" 'burdock-structured-wrap-lambda)
  (define-key evil-normal-state-local-map "WL" 'burdock-structured-wrap-lambda-call)
  (define-key evil-normal-state-local-map [down] 'burdock-zip-down)
  (define-key evil-normal-state-local-map [up] 'burdock-zip-up)
  (define-key evil-normal-state-local-map [left] 'burdock-zip-left)
  (define-key evil-normal-state-local-map [right] 'burdock-zip-right))

(add-hook 'ruby-mode-hook 'burdock-mode)
(add-hook 'burdock-mode-hook '~/define-evil-keys-for-burdock-mode)
(add-hook 'burdock-mode-hook 'burdock-start)
