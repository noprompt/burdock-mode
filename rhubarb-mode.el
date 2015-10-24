;;; TODO: Handle chunked responses
;;;   - partially complete
;;; TODO: All sent messages should
;;;   - permit a callback associated with `id'.
;;; TODO: Mappings
;;;   - rhubarb-up -> Rhubarb::Zipper.up at loc
;;;   - rhubarb-down -> Rhubarb::Zipper.down at loc
;;;   - rhubarb-left -> Rhubarb::Zipper.left at loc
;;;   - rhubarb-leftmost -> Rhubarb::Zipper.leftmost at loc
;;;   - rhubarb-right -> Rhubarb::Zipper.right at loc
;;;   - rhubarb-rightmost -> Rhubarb::Zipper.rightmost at loc
;;; TODO: Rename lvar
;;; TODO: Extract YARD

(require 'json)
(require 'color)

(defvar rhubarb-mode-map
  (make-sparse-keymap)
  "TODO")

(define-minor-mode rhubarb-mode
  "TODO"
  :lighter " Rhubarb"
  :keymap rhubarb-mode-map)


;; ---------------------------------------------------------------------
;; Global configuration

(defconst rhubarb-show-sexp-buffer nil
  "TODO")

(defun rhubarb-toggle-show-sexp-buffer ()
  (interactive)
  (setq rhubarb-show-sexp-buffer (not rhubarb-show-sexp-buffer)))

(defconst rhubarb-sexp-at-point-enabled nil
  "TODO")

(defun rhubarb-toggle-sexp-at-point ()
  (interactive)
  (setq rhubarb-sexp-at-point-enabled
	(not rhubarb-sexp-at-point-enabled)))


;; ---------------------------------------------------------------------
;; Process variables

(defconst rhubarb-process nil
  "TODO")

(defvar rhubarb-cli-arguments '()
  "TODO")


;; ---------------------------------------------------------------------
;; Overlay variables/management

;; Sexp overlay

(defconst rhubarb-highlight-sexp nil
  "TODO")

(defvar rhubarb-sexp-overlay nil
  "Overlay for highlighting the current sexp at point.")

(defun rhubarb-ensure-sexp-overlay ()
  "Ensures `rhubarb-sexp-overlay' exists."
  (when (not (overlayp rhubarb-sexp-overlay))
    (set (make-local-variable 'rhubarb-sexp-overlay)
	 (make-overlay 0 0))))

(defun rhubarb-clear-sexp-overlay ()
  (rhubarb-ensure-sexp-overlay)
  (move-overlay rhubarb-sexp-overlay 0 0))

(defun rhubarb-move-sexp-overlay (begin-pos end-pos)
  (rhubarb-ensure-sexp-overlay)
  (overlay-put rhubarb-sexp-overlay
	       'face
	       `(t . ((:background ,(-> (face-attribute 'default :background)
				      (color-lighten-name 2))))))
  (move-overlay rhubarb-sexp-overlay begin-pos end-pos))

(defun rhubarb-toggle-highlight-sexp ()
  (interactive)
  (when rhubarb-highlight-sexp
    (rhubarb-clear-sexp-overlay))
  (setq rhubarb-highlight-sexp (not rhubarb-highlight-sexp)))


;; Error overlay

(defvar rhubarb-error-overlay nil
  "Overlay for highlighting syntax errors.")

(defun rhubarb-ensure-error-overlay ()
  "Ensures `rhubarb-error-overlay' exists."
  (when (not (overlayp rhubarb-error-overlay))
    (set (make-local-variable 'rhubarb-error-overlay)
	 (make-overlay 0 0))))

(defun rhubarb-clear-error-overlay ()
  (rhubarb-ensure-error-overlay)
  (move-overlay rhubarb-error-overlay 0 0))

(defun rhubarb-move-error-overlay (begin-pos end-pos)
  (overlay-put rhubarb-error-overlay
	       'face
	       `(t . ((:foreground ,(face-attribute 'font-lock-warning-face :foreground))
		      (:underline t))))
  (move-overlay rhubarb-error-overlay begin-pos end-pos))

;; ---------------------------------------------------------------------
;; REPL utilities

(defun rhubarb-repl-clear-buffer ()
  "Clears the `inf-ruby-buffer' if it exists."
  (interactive)
  (when (bufferp (get-buffer inf-ruby-buffer))
    (with-current-buffer inf-ruby-buffer
      (let ((comint-buffer-maximum-size 0))
	(comint-truncate-buffer))))) 

(defun rhubarb-repl-send-lines (lines)
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
;; Response handling

(defconst rhubarb-method-table
  (make-hash-table :test 'equal))

(defun rhubarb-dispatch (rhubarb-response)
  (let* ((method (plist-get rhubarb-response :method))
	 (handler (gethash method rhubarb-method-table)))
    (when handler
      (funcall handler rhubarb-response))))

(defun rhubarb-add-response-listener (method fn)
  (puthash method fn rhubarb-method-table))

(defun rhubarb-handle-message (rhubarb-response)
  (message (plist-get rhubarb-response :message)))

(defun rhubarb-handle-eval (rhubarb-response)
 (let ((params (plist-get rhubarb-response :params)))
   (rhubarb-repl-send-lines
    (-mapcat
     (lambda (s)
       (s-split "\n" s))
     params))))

(defun rhubarb-handle-sexp (rhubarb-response)
  (let* ((params (plist-get rhubarb-response :params))
	 (sexps (plist-get params :sexps))
	 (begin-pos (plist-get params :begin_pos))
	 (end-pos (plist-get params :end_pos)))
    (when rhubarb-show-sexp-buffer
      (with-current-buffer (get-buffer-create "*rhubarb-sexp*")
	(rhubarb-sexp-mode)
	(erase-buffer)
	(dotimes (i (length sexps))
	  (insert (elt sexps i)))))

    (when rhubarb-highlight-sexp
      (rhubarb-move-sexp-overlay begin-pos end-pos))))

(defun rhubarb-handle-edit-delete-region (rhubarb-response)
  (let* ((params (plist-get rhubarb-response :params))
	 (begin-pos (plist-get params :begin_pos))
	 (end-pos (plist-get params :end_pos)))
    (kill-region begin-pos end-pos)))

(defun rhubarb-handle-edit-replace-region (rhubarb-response)
  (let* ((params (plist-get rhubarb-response :params))
	 (begin-pos (plist-get params :begin_pos))
	 (end-pos (plist-get params :end_pos))
	 (insertion (plist-get params :insertion)))
    (delete-region begin-pos end-pos)
    (save-excursion
     (goto-char begin-pos)
     (insert insertion)
     ;; HACK: This should be removed once callbacks are implemented.
     (indent-region begin-pos (point)))))

(defun rhubarb-handle-edit-insert (rhubarb-response)
  (let* ((params (plist-get rhubarb-response :params))
	 (begin-pos (plist-get params :begin_pos))
	 (insertion (plist-get params :insertion))
	 (insertion-length (length insertion))
	 (end-pos (+ begin-pos insertion-length))
	 (end-pos (if (s-ends-with? "\n" insertion)
		      (+ end-pos 1)
		    end-pos)))
    (save-excursion
      (goto-char begin-pos)
      (insert insertion)
      (indent-region begin-pos end-pos))))


(rhubarb-add-response-listener "message" 'rhubarb-handle-message)
(rhubarb-add-response-listener "sexp" 'rhubarb-handle-sexp)
(rhubarb-add-response-listener "eval" 'rhubarb-handle-eval)
(rhubarb-add-response-listener "edit-replace-region" 'rhubarb-handle-edit-replace-region)
(rhubarb-add-response-listener "edit-delete-region" 'rhubarb-handle-edit-delete-region)
(rhubarb-add-response-listener "edit-insert" 'rhubarb-handle-edit-insert)

;; ---------------------------------------------------------------------
;; Response parsing

(defconst rhubarb-response-buffer ""
  "TODO")

(defun rhubarb-parse-response (response-string)
  (unwind-protect
      (condition-case ex
	  (let* ((json-object-type 'plist))
	    (json-read-from-string response-string))
	('error
	 (message "Error parsing response: %S" response-string)))
    nil))

;; ---------------------------------------------------------------------
;; Error buffer

(defun rhubarb-derive-backtrace-components (backtrace-line)
  (let* ((backtrace-components (split-string backtrace-line ":" t))
	 (backtrace-file-path (nth 0 backtrace-components))
	 (backtrace-line-number (string-to-int (nth 1 backtrace-components))))
    `(:file-path ,backtrace-file-path :line-number ,backtrace-line-number)))

(defun rhubarb-fontify-ruby (text-to-fontify)
  (with-temp-buffer
    (insert text-to-fontify)
    (delay-mode-hooks (ruby-mode))
    (font-lock-default-function 'ruby-mode)
    (font-lock-default-fontify-region (point-min)
				      (point-max)
				      nil)
    (let* ((text (buffer-string))
	   (pos 0))
      (while (setq next (next-single-property-change pos 'face text))
	(put-text-property pos next 'font-lock-face (get-text-property pos 'face text) text)
	(setq pos next))
      (add-text-properties 0 (length text) '(fontified t) text)
      text)))

(defun rhubarb-line-number-format-string (line-number)
  (concat "%-"
	  (number-to-string (length (number-to-string line-number)))
	  "d"))

(defun* rhubarb-derive-backtrace-context (backtrace-line &optional &key context-amount &allow-other-keys)
  (let* ((backtrace-components (rhubarb-derive-backtrace-components backtrace-line))
	 (file-path (plist-get backtrace-components :file-path))
	 (line-number (plist-get backtrace-components :line-number))
	 (context-amount (or context-amount 3)))
    (with-temp-buffer
      (insert-file-contents file-path)
      (let* ((fontified-text (rhubarb-fontify-ruby (buffer-string)))
	     (total-lines (count-lines (point-min) (point-max)))
	     (context-line-start (max 1 (- line-number context-amount)))
	     (context-line-end (min total-lines (+ line-number context-amount)))
	     (context-line-number-format (rhubarb-line-number-format-string context-line-end)))
	(erase-buffer)
	(insert fontified-text)
	(goto-line context-line-start)
	(dotimes (i (+ (- context-line-end context-line-start) 1))
	  (beginning-of-line)
	  (insert (format context-line-number-format (line-number-at-pos)))
	  (next-line))
	(let ((context-start-point (progn
				     (goto-line context-line-start)
				     (point)))
	      (context-end-point (progn
				   (goto-line context-line-end)
				   (end-of-line)
				   (point)))) 
	  (buffer-substring context-start-point context-end-point))))))

;; ---------------------------------------------------------------------
;; Error response handling

(defconst rhubarb-last-error-data nil
  "TODO")

(defun rhubarb-highlight-offending-expression (line-start line-end column-start column-end)
  (save-excursion
    (let* ((error-begin-point (progn
				(goto-line line-start)
				(move-to-column column-start)
				(point)))
	   (error-end-point (progn
			      (goto-line line-end)
			      (move-to-column column-end)
			      (point))))
      (rhubarb-move-error-overlay error-begin-point error-end-point))))

(defun rhubarb-display-error-message-and-backtrace (error-messsage backtrace)
  (with-current-buffer (get-buffer-create "*rhubarb-error*")
    (erase-buffer)
    (insert (concat error-message "\n"))
    (dotimes (i (length backtrace))
      (let* ((backtrace-line (elt backtrace i)))
	(insert backtrace-line)
	(insert "\n")
	(comment
	 (insert (rhubarb-derive-backtrace-context backtrace-line))
	 (insert "\n\n"))))
    (beginning-of-buffer)))

(defun rhubarb-handle-error-response (response-plist)
  (let* ((error-data (plist-get response-plist :error)))
    (when (not (equal rhubarb-last-error-data error-data))
      (setq rhubarb-last-error-data error-data)
      (let* ((error-message (plist-get error-data :message))
	     (backtrace (plist-get error-data :trace))
	     (line-start (plist-get error-data :line_start))
	     (line-end (plist-get error-data :line_end))
	     (column-start (plist-get error-data :column_start))
	     (column-end (plist-get error-data :column_end)))
	(when (and line-start line-end column-start column-end)
	  (rhubarb-highlight-offending-expression line-start line-end column-start column-end))
	(rhubarb-display-error-message-and-backtrace error-message backtrace)))))

(defun rhubarb-kill-error-buffer ()
  (when (bufferp (get-buffer "*rhubarb-error*"))
    (with-current-buffer "*rhubarb-error*"
      (kill-buffer))))

(defun rhubarb-cease-error-state ()
  (rhubarb-clear-error-overlay)
  (rhubarb-kill-error-buffer)
  (setq rhubarb-last-error-data nil))

(defun rhubarb-handle-response-string
  (response-string)
  (let* ((complete-response-string (concat rhubarb-response-buffer response-string)))
    (if (s-ends-with? "\n" complete-response-string)
	(progn
	  (let* ((response-plist (rhubarb-parse-response complete-response-string)))
	    (when response-plist
	      (if (plist-get response-plist :error)
		  (rhubarb-handle-error-response response-plist)
		(let* ((result (plist-get response-plist :result)))
		  (rhubarb-cease-error-state)
		  (rhubarb-dispatch result)))))
	  (setq rhubarb-response-buffer ""))
      (setq rhubarb-response-buffer complete-response-string))))


;; ---------------------------------------------------------------------
;; Process filter 

(defvar rhubarb-process-filter
  (lambda (proc response-string)
    (rhubarb-handle-response-string response-string)))


;; ---------------------------------------------------------------------
;; Process initialization hooks 

(defun rhubarb-post-command ()
  (when (and (process-live-p rhubarb-process)
	     (not (region-active-p)))
    (when rhubarb-sexp-at-point-enabled
      (rhubarb-sexp-at-point))))

(defun rhubarb-after-change-hook (start-point end-point length)
  (when (process-live-p rhubarb-process)
    (rhubarb-update-buffer start-point end-point length)))

(defun rhubarb-initialize-process ()
  (when (or (not rhubarb-process)
	    (not (process-live-p rhubarb-process)))
    (let* ((process-connection-type nil) ;; Use a pipe.
	   (process (start-process "*rhubarb*" nil
				   "ruby" "/Users/noprompt/git/noprompt/rhubarb-mode/ruby/rhubarb.rb")))
      (set-process-filter process rhubarb-process-filter)
      (setq rhubarb-process process))))

(defun rhubarb-initialize-local-hooks ()
  (interactive)
  (add-hook 'after-change-functions 'rhubarb-after-change-hook nil t)
  (add-hook 'post-command-hook 'rhubarb-post-command nil t))

;; ---------------------------------------------------------------------
;; Process control and status

(defun rhubarb-start ()
  "Starts the `rhubarb-process'."
  (interactive)
  (rhubarb-initialize-process)
  (rhubarb-initialize-buffer)
  (rhubarb-initialize-local-hooks))

(defun rhubarb-stop ()
  "Stops the `rhubarb-process' if it is live."
  (interactive)
  (when (process-live-p rhubarb-process)
    (kill-process rhubarb-process)
    (setq-local rhubarb-process nil)))

(defun rhubarb-restart ()
  "Restarts the `rhubarb-process'."
  (interactive)
  (rhubarb-stop)
  (rhubarb-start))

(defun rhubarb-status ()
  (interactive)
  (message "%s" (process-status rhubarb-process)))

;; ---------------------------------------------------------------------
;; Message construction

(defun rhubarb-build-message-payload (method &rest params)
  (let* ((request-id (symbol-name (gensym)))
	 (buffer-id (or (buffer-file-name)
			(buffer-name)))
	 (buffer-current-point (point))
	 (buffer-current-line (line-number-at-pos))
	 (buffer-current-column (current-column))
	 (params `(,@params
		   :buffer-id ,buffer-id
		   :buffer-current-point ,buffer-current-point
		   :buffer-current-line ,buffer-current-line
		   :buffer-current-column ,buffer-current-column)))
    (json-encode `(:id ,request-id :method ,method :params ,params))))

(defun rhubarb-build-message (method &rest params)
  (concat (apply 'rhubarb-build-message-payload (cons method params)) "\n"))

(defun rhubarb-send-message (method &rest params)
  (let* ((request-string (apply 'rhubarb-build-message method params)))
    (process-send-string rhubarb-process request-string)))

(defun rhubarb-initialize-buffer ()
  (interactive)
  (let* ((buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
    (rhubarb-send-message "initialize-buffer"
			  :buffer-contents buffer-contents)))

(defun rhubarb-update-buffer (start-point end-point length)
  (let* ((value (buffer-substring-no-properties start-point end-point)))
    (rhubarb-send-message "update-buffer"
			  :start-point start-point
			  :end-point end-point
			  :length length
			  :value value)))

;; ---------------------------------------------------------------------
;; Sexp extraction

(defun rhubarb-defun-at-point ()
  (interactive)
  (let* ((line-number (line-number-at-pos)))
    (rhubarb-send-message "defun-at-point")))

(defun rhubarb-sexp-at-point ()
  (interactive)
  (let* ((line-number (line-number-at-pos))
	 (column-number (current-column)))
    (rhubarb-send-message "sexp-at-point")))


;; ---------------------------------------------------------------------
;; Evaluation

(defun rhubarb-test-eval ()
  (interactive)
  (rhubarb-send-message "test-eval"))

(defun rhubarb-eval-defun ()
  (interactive)
  (let* ((line-number (line-number-at-pos)))
    (rhubarb-send-message "eval-defun")))

(defun rhubarb-load-from-temp-file ()
  (let* ((temp-file (make-temp-file "rhubarb"))
	 (buffer-contents (buffer-substring-no-properties (point-min) (point-max))))
    (with-temp-file temp-file
      (insert buffer-contents))
    (rhubarb-repl-send-lines `(,(format "load('%s') # From buffer %s" temp-file (buffer-name))))))

(defun rhubarb-load-file ()
  (interactive)
  (if (buffer-file-name)
      (rhubarb-repl-send-lines `(,(format "load('%s') # From buffer %s"
					  (buffer-file-name)
					  (buffer-name))))
    (rhubarb-load-from-temp-file)))


;; ---------------------------------------------------------------------
;; Structured editing

;; TODO: `rhubarb-structured-forward-copy-as-kill'

(defun rhubarb-structured-forward-delete ()
  (interactive)
  (rhubarb-send-message "forward-delete"))

(defun rhubarb-structured-forward-kill ()
  (interactive)
  (rhubarb-send-message "forward-kill"))

(defun rhubarb-structured-wrap-round ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["(" ")"]))

(defun rhubarb-structured-wrap-square ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["[" "]"]))

(defun rhubarb-structured-wrap-curly ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["{" "}"]))

(defun rhubarb-structured-wrap-pipe ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["|" "|"]))

(defun rhubarb-structured-wrap-dquote ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["\"" "\""]))

(defun rhubarb-structured-wrap-squote ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["'" "'"]))

(defun rhubarb-structured-wrap-do ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["do\n" "\nend"]))

(defun rhubarb-structured-wrap-if (test)
  (interactive "sTest: ")
  (rhubarb-send-message "structured-wrap" :pair `[,(concat "if " test "\n") "\nend"]))

(defun rhubarb-structured-wrap-unless (test)
  (interactive "sTest: ")
  (rhubarb-send-message "structured-wrap" :pair `[,(concat "unless " test "\n") "\nend"]))

(defun rhubarb-structured-wrap-lambda ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["lambda do\n" "\nend"]))

(defun rhubarb-structured-wrap-lambda-call ()
  (interactive)
  (rhubarb-send-message "structured-wrap" :pair ["lambda do\n" "\nend.call"]))

(defun rhubarb-structured-wrap-def (def-name)
  (interactive "sMethod name: ")
  (rhubarb-send-message "structured-wrap" :pair `[,(concat "def " def-name "()\n") "\nend"]))

(defun rhubarb-structured-wrap-class (class-name)
  (interactive "sClass name: ")
  (rhubarb-send-message "structured-wrap" :pair `[,(concat "class " class-name "\n") "\nend"]))

(defun rhubarb-structured-wrap-module (module-name)
  (interactive "sModule name: ")
  (rhubarb-send-message "structured-wrap" :pair `[,(concat "module " module-name "\n") "\nend"]))


;; ---------------------------------------------------------------------
;; Miscellaneous

(defun rhubarb-extract-yard-doc ()
  (interactive)
  (rhubarb-send-message "extract-yard-doc"))

(add-hook 'ruby-mode-hook 'rhubarb-mode)
(add-hook 'rhubarb-mode-hook 'rhubarb-start)

(defun noprompt-define-evil-keys-for-rhubarb-mode ()
  (interactive)
  (define-key evil-normal-state-local-map ",e" 'rhubarb-eval-defun)
  (define-key evil-normal-state-local-map "W(" 'rhubarb-structured-wrap-round)
  (define-key evil-normal-state-local-map "W[" 'rhubarb-structured-wrap-square)
  (define-key evil-normal-state-local-map "W{" 'rhubarb-structured-wrap-curly)
  (define-key evil-normal-state-local-map "W|" 'rhubarb-structured-wrap-pipe)
  (define-key evil-normal-state-local-map "W\"" 'rhubarb-structured-wrap-dquote)
  (define-key evil-normal-state-local-map "W'" 'rhubarb-structured-wrap-squote)
  (define-key evil-normal-state-local-map "Wi" 'rhubarb-structured-wrap-if)
  (define-key evil-normal-state-local-map "Wu" 'rhubarb-structured-wrap-unless)
  (define-key evil-normal-state-local-map "Wd" 'rhubarb-structured-wrap-do)
  (define-key evil-normal-state-local-map "WD" 'rhubarb-structured-wrap-def)
  (define-key evil-normal-state-local-map "Wc" 'rhubarb-structured-wrap-class)
  (define-key evil-normal-state-local-map "Wm" 'rhubarb-structured-wrap-module)
  (define-key evil-normal-state-local-map "Wl" 'rhubarb-structured-wrap-lambda)
  (define-key evil-normal-state-local-map "WL" 'rhubarb-structured-wrap-lambda-call)
  (define-key evil-normal-state-local-map "D" 'rhubarb-structured-forward-kill)
  (define-key evil-normal-state-local-map ",l" 'rhubarb-load-file))

(add-hook 'rhubarb-mode-hook 'noprompt-define-evil-keys-for-rhubarb-mode)

;; ---------------------------------------------------------------------
;; Sexp buffer

(defvar rhubarb-sexp-mode-keywords
  '("alias"
    "and"
    "array"
    "arg"
    "args"
    "begin"
    "block"
    "blockarg"
    "case"
    "casgn"
    "cbase"
    "class"
    "const"
    "cvar"
    "def"
    "defs"
    "defined?"
    "dstr"
    "ensure"
    "erange"
    "false"
    "for"
    "gvar"
    "gvasgn"
    "hash"
    "if"
    "int"
    "irange"
    "ivar"
    "ivasgn"
    "kwbegin"
    "kwoptarg"
    "lvar"
    "lvasgn"
    "masgn"
    "mlhs"
    "module"
    "op-asgn"
    "or"
    "pair"
    "redo"
    "regexp"
    "regopt"
    "resbody"
    "rescue"
    "restarg"
    "retry"
    "return"
    "self"
    "send"
    "splat"
    "splat"
    "str"
    "sym"
    "true"
    "undef"
    "until"
    "when"
    "while"
    "yield"
    "zsuper"))

(define-derived-mode rhubarb-sexp-mode fundamental-mode
  "Rhubarb Sexp" 
  (setq font-lock-defaults
	`(((,(concat "\\_<" (regexp-opt rhubarb-sexp-mode-keywords) "\\_>")
	    . font-lock-keyword-face)
	   (":[^\s()]+"
	    . font-lock-constant-face)
	   ("\\_<nil\\_>"
	    . font-lock-variable-name-face)))))

(define-key ruby-mode-map (kbd "C-c C-l") 'rhubarb-load-file)

(provide 'rhubarb-mode)
