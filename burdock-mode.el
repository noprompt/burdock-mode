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
  nil
  "The Burdock Ruby source directory."
  :type '(file :must-match t)
  :group 'burdock-mode)

;; ---------------------------------------------------------------------
;; burdock-error

(defun burdock-error-buffer ()
  "Buffer where Burdock errors will be displayed."
  (get-buffer-create "*burdock-error*"))

(defun burdock-display-error-in-buffer (error-content)
  "Display the value of `error-content' in `burdock-error-buffer'."
  (with-current-buffer (burdock-error-buffer)
    (erase-buffer)
    (insert error-content))
  ;; TODO: Make displaying this buffer optional.
  (display-buffer (burdock-error-buffer)))


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
exists.

This function deliberately emulates a programmer entering input at the
REPL line-by-line. Sending the source lines directly to the process
with `comint-send-string', as with the `ruby-send-*' functions, often
produces strange output in `inf-ruby-buffer' such as the following.

    [22] pry(main)> SyntaxError: unexpected keyword_end, expecting end-of-input
    [23] pry(main)> => 2
    [24] pry(main)> [24] pry(main)* [24] pry(main)* => :initialize

This output is unacceptable. By emulating line-by-line entry the REPL
output is consistent with manual REPL behavior.

    [51] pry(main)> class Foo
    [51] pry(main)*   def initialize(foo)
    [51] pry(main)*     @foo = foo
    [51] pry(main)*   end
    [51] pry(main)* end
    => :initialize
"
  (when (bufferp (get-buffer inf-ruby-buffer))
    (let ((buff (current-buffer)))
      (with-current-buffer inf-ruby-buffer
	;; HACK: I have no idea why this is necessary but without it
	;; the REPL breaks when the point in the `inf-ruby-buffer' is
	;; anywhere other than `point-max'.
	(goto-char (point-max))
	(dolist (line lines)
	  ;; HACK: This ensures that each line of input is preceded by the
	  ;; prompt in IRB. For Pry `Pry.config.auto_indent = false' can
	  ;; be specified in the ~/.pryrc to preven issues with the
	  ;; prompt. The 5 millisecond sleep seems produce the best
	  ;; result.
	  (insert line)
	  (sleep-for 0 5)
	  (call-interactively (key-binding (kbd "<RET>"))))))))


;; ---------------------------------------------------------------------
;; burdock-client

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

(defvar burdock-callback-table
  (make-hash-table :test 'equal)
  "Hash table mapping request ids to callbacks.")

(defun burdock-send-request (burdock-process request-data &optional callback)
  "Encodes the contents of `request-data' as JSON and sends it to
`burdock-process'. If the optional `callback' is provided it will be
stored in `burdock-callback-table' and called when response
corresponding to this request is received."
  (let* ((id (burdock-uuid-create))
	 (request-data-with-id (cons `(id . ,id) request-data))
	 (request-string (json-encode request-data-with-id)))
    (puthash id (or callback 'identity) burdock-callback-table)
    (process-send-string burdock-process request-string)
    (process-send-string burdock-process "\n")))

(defun burdock-receive-response (burdock-process response-string)
  "Default function used by `burdoc-process-filter' responsible for
decoding `response-string' from JSON and calling a corresponding
callback, if any, with the decoded JSON data.

JSON is decoded as an alist with `json-read-from-string'."
  (condition-case nil
      (let* ((response-data (json-read-from-string response-string))
	     (id (cdr (assoc 'id response-data)))
	     (callback (gethash id burdock-callback-table 'identity)))
	(funcall callback response-data)
	(remhash id burdock-callback-table))
    (json-error
     (with-current-buffer (burdock-response-buffer)
       (erase-buffer))

     (burdock-display-error-in-buffer
      (concat "There was a problem parsing the following message.\n"
	      response-string)))))

(defun burdock-error-response-p (response-data)
  "Returns t if `response-data' contains an entry for the key 'error."
  (assoc 'error response-data))

(defun burdock-success-response-p (response-data)
  "Returns t if `response-data' contains an entry for the key 'error."
  (not (burdock-error-response-p response-data)))

(defun burdock-get-parameter (key response-data)
  "Retrieve the value of `key' from the value of the key 'params in
`response-data'."
  (cdr (assoc key (cdr (assoc 'params response-data)))))

;; ---------------------------------------------------------------------
;; burdock-process

(defconst burdock-process nil
  "The Burdock ruby process.")

(defconst burdock-response-sentinel
  "\0\0"
  "Character sequence used to signal the end of a reponse.")

(defun burdock-response-buffer ()
  "Buffer responsible for holding output temporarily from
`burdock-process'."
  (get-buffer-create "*burdock-response-buffer*"))

(defun burdock-write-response-chunk-to-buffer (response-string)
  "Writes `response-string' to the buffer given by
`burdock-response-buffer.'"
  (with-current-buffer (burdock-response-buffer)
    (goto-char (point-max))
    (insert response-string)))

(defun burdock-read-response-from-buffer (callback)
  "Attemps to read a complete response from `burdock-response-buffer'
passing it to `callback' if successful."
  (let ((maybe-response (with-current-buffer (burdock-response-buffer)
			  (goto-char (point-min))
			  (let ((maybe-point (search-forward burdock-response-sentinel nil t)))
			    (when maybe-point
			      (let ((response (buffer-substring-no-properties (point-min) (point))))
				(delete-region (point-min) (point))
				(string-trim-right response)))))))
    (when maybe-response
      (funcall callback maybe-response))))

(defvar burdock-process-filter
  (lambda (process response-string)
    (burdock-write-response-chunk-to-buffer response-string)
    (burdock-read-response-from-buffer
     (lambda (response)
       (burdock-receive-response process response))))
  "Process filter for `burdock-process'.")

(defun burdock-initialize-process ()
  (when (or (not burdock-process)
	    (not (process-live-p burdock-process)))
    (let* ((process-connection-type nil) ;; Use a pipe.
	   (process (let ((default-directory burdock-ruby-source-directory))
		      (start-process "*burdock*" nil "bundle" "exec" "bin/burdock"))))
      (set-process-filter process burdock-process-filter)
      (setq burdock-process process))))

(defun burdock-start ()
  "Starts `burdock-process'."
  (interactive)
  (burdock-initialize-process))

(defun burdock-stop ()
  "Stops `burdock-process' if it is live."
  (interactive)
  (when (process-live-p burdock-process)
    (kill-process burdock-process)
    (setq-local burdock-process nil)))

(defun burdock-restart ()
  "Restarts `burdock-process'."
  (interactive)
  (burdock-stop)
  (burdock-start))

(defun burdock-status ()
  (interactive)
  (message "%s" (process-status burdock-process)))


;; ---------------------------------------------------------------------
;; burdock-core

(defun burdock-emacs-point-to-burdock-point (emacs-point)
  "Given an Emacs point, return a point value compatible with the
Burdock server."
  (- emacs-point 1))

(defun burdock-emacs-point-from-burdock-point (burdock-point)
  "Given an point value from the Burdock server, convert it to a point
value compatible for Emacs."
  (+ burdock-point 1))

(defun burdock-base-parameters ()
  "Parameters essential in virtually every request. Includes the
current buffer content, point, line number, and column number."
  (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
	 (burdock-point (burdock-emacs-point-to-burdock-point (point)))
	 (line-number (line-number-at-pos))
	 (column-number (current-column)))
    `((column . ,column-number)
      (line-number . ,line-number)
      (point . ,burdock-point)
      (source . ,source))))

(defun burdock-request (method &optional parameters)
  "Constructs a burdock request object (an alist) but does not send
it. `method' should either a string or symbol. `parameters' should be
alist."
  (let ((params (append parameters (burdock-base-parameters))))
    `((method . ,method)
      (params . ,params))))

(defun burdock-goto-start-point (response-data)
  "Helper function used to go to the value of a starting point as
provided by `response-data'."
  (when (burdock-success-response-p response-data)
    (let ((start-point (burdock-get-parameter 'start_point response-data)))
      (when start-point
	(let ((start-point (burdock-emacs-point-from-burdock-point start-point)))
	  (goto-char start-point))))))

(defun burdock-evaluate-source (response-data)
  "Helper function which sends source code provided by `response-data' to the
current Ruby process."
  (when (burdock-success-response-p response-data)
    (let ((source (burdock-get-parameter 'source response-data)))
      (when source
	(burdock-repl-send-lines (split-string source "\n"))))))

(defun burdock-zip-left ()
  "Move to the sibling to the left of the node at the current position
in a structural fashion."
  (interactive)
  (let* ((request (burdock-request "burdock/zip-left")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-right ()
  "Move to the sibling to the right of the node at the current position
in a structural fashion."
  (interactive)
  (let* ((request (burdock-request "burdock/zip-right")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-up ()
  "Move to the parent the node at the current position in a structural
fashion."
  (interactive)
  (let* ((request (burdock-request "burdock/zip-up")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-zip-down ()
  "Move to the first child of the node at the current position in a
structural fashion."
  (interactive)
  (let* ((request (burdock-request "burdock/zip-down")))
    (burdock-send-request burdock-process request 'burdock-goto-start-point)))

(defun burdock-evaluate-expression-at-point ()
  "Evaluate the expression at the current position in a structural
fashion. Equivalent to evaluating a single node in an AST. Note
the extracted expression to be evaluated will be semantically
equivalent but not syntactically equivalent."
  (interactive)
  (let* ((request (burdock-request "burdock/expression-at-point")))
    (burdock-send-request burdock-process request 'burdock-evaluate-source)))

(defun burdock-evaluate-scope-at-point ()
  "Evaluate the expression at the current position in a structural
fashion with respect to Ruby scope in the current Ruby process. Note
the extracted expression to be evaluated will be semantically
equivalent but not syntactically equivalent.

The following Ruby code and legend provide an overview of the
extraction process by example.

    class Foo
      # (A)

      attr_reader :bar # (B)
      attr_reader :baz

      def initialize(bar, baz)
	@bar = bar # (C)
	@baz = baz # (C)
      end
    end

In position (A) the extraction includes the entirety of the class
definition.

    class Foo
      attr_reader :bar
      attr_reader :baz
      def initialize(bar, baz)
        @bar = bar
	@baz = baz
      end
    end

In position (B) with the cursor anywhere inside the att_reader
expression will result in the following extraction.

    class Foo
      attr_reader :bar
    end

Notice the attr_reader for :baz was not extracted.

In position (C) with the cursor anywhere inside the def expression
will result in the following extraction.

    class Foo
      def initialize(bar, baz)
        @bar = bar
	@baz = baz
      end
    end
"
  (interactive)
  (let* ((request (burdock-request "burdock/scope-at-line")))
    (burdock-send-request burdock-process request 'burdock-evaluate-source)))

(defun burdock-structured-wrap (left-delimiter right-delimiter &optional post-hook)
  "Wrap the expression at the current position with `left-delimiter'
and `right-delimiter' in a structured fashion. Calls the optional
function `post-hook' with the start and end point of the full wrapped
expression."
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
  "In a structured fashion, wrap the expression at the current
position with round brackets."
  (interactive)
  (burdock-structured-wrap "(" ")"))

(defun burdock-structured-wrap-square ()
  "In a structured fashion, wrap the expression at the current
position with square brackets."
  (interactive)
  (burdock-structured-wrap "[" "]"))

(defun burdock-structured-wrap-curly ()
  "In a structured fashion, wrap the expression at the current
position with curly brackets."
  (interactive)
  (burdock-structured-wrap "{" "}"))

(defun burdock-structured-wrap-double-quote ()
  "In a structured fashion, wrap the expression at the current
position with double quotes."
  (interactive)
  (burdock-structured-wrap "\"" "\""))

(defun burdock-structured-wrap-single-quote ()
  "In a structured fashion, wrap the expression at the current
position with single quotes."
  (interactive)
  (burdock-structured-wrap "'" "'"))

(defun burdock-structured-wrap-lambda ()
  "In a structured fashion, wrap the expression at the current
position with \"lambda do\" and \"end\" then reindent."
  (interactive)
  (burdock-structured-wrap "lambda do\n" "\nend"
			   (lambda (start-point end-point)
			     (indent-region start-point end-point))))

(defun burdock-structured-wrap-lambda-call ()
  "In a structured fashion, wrap the expression at the current
position with \"lambda do\" and \"end.call\" then reindent."
  (interactive)
  (burdock-structured-wrap "lambda do\n" "\nend.call"
			   (lambda (start-point end-point)
			     (indent-region start-point end-point))))

(defun budock-s-expression-at-point ()
  (interactive)
  (let ((request (burdock-request "burdock/s-expression-at-point")))
    (burdock-send-request burdock-process request
			  (lambda (response-data)
			    (let ((s-expression (burdock-get-parameter 's_expression response-data)))
			      (message "%s" s-expression))))))

;; ---------------------------------------------------------------------
;; burdock-s-expression

(defvar burdock-s-expression-mode-keywords
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

(define-derived-mode burdock-s-expression-mode fundamental-mode
  "Rhubarb Sexp" 
  (setq font-lock-defaults
	`(((,(concat "\\_<" (regexp-opt burdock-s-expression-mode-keywords) "\\_>")
	    . font-lock-keyword-face)
	   (":[^\s()]+"
	    . font-lock-constant-face)
	   ("\\_<nil\\_>"
	    . font-lock-variable-name-face)))))

(defvar burdock-s-expression-timer
  nil
  "TODO")

(defun burdock-s-expression-buffer ()
  (if (not (buffer-live-p (get-buffer "*burdock-s-expression*")))
      (with-current-buffer (get-buffer-create "*burdock-s-expression*")
	(burdock-s-expression-mode))
    (get-buffer-create "*burdock-s-expression*")))

(defun burdock-show-s-expression-at-point-in-buffer ()
  (interactive)
  (let ((request (burdock-request "burdock/s-expression-at-point")))
    (burdock-send-request burdock-process request
			  (lambda (response-data)
			    (if (burdock-success-response-p response-data)
				(let ((s-expression (burdock-get-parameter 's_expression response-data)))
				  (display-buffer (burdock-s-expression-buffer))
				  (with-current-buffer (burdock-s-expression-buffer)
				    (erase-buffer)
				    (insert s-expression)))
			      nil)))))

(defun burdock-run-s-expression-timer-function ()
  (setq burdock-s-expression-timer
	(run-with-idle-timer
	 0.5
	 t
	 (lambda ()
	   (when (bound-and-true-p burdock-mode)
	     (burdock-show-s-expression-at-point-in-buffer))))))

(defun burdock-disable-s-expression-buffer ()
  "Disable the display of the underlying s-expression with respect to
`point' whenever idle."
  (interactive)
  (when burdock-s-expression-timer
    (cancel-timer burdock-s-expression-timer)
    (setq burdock-s-expression-timer nil)))

(defun burdock-enable-s-expression-buffer ()
  "Enable the display of the underlying s-expression with respect to
`point' whenever idle."
  (interactive)
  (when (not burdock-s-expression-timer)
    (burdock-run-s-expression-timer-function)))

(provide 'burdock-mode)
