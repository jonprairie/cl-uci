(in-package #:cl-uci)

(defvar +square-regex+ "[a-h][1-8]")
(defvar +lan-move-regex+ (concatenate 'string
				      "(" +square-regex+ ")"
				      "(" +square-regex+ ")"
				      "([qbnr]?)"))
(defvar +best-move-regex+ (concatenate 'string
				       "^bestmove "
				       "(" +lan-move-regex+ ")"))

(defmacro ret-n (n &body body)
  "returns the Nth (zero-based) value from BODY"
  (with-gensyms (ret-value)
    `(let+ (((&values ,@(loop for x from 1 to (max 0 n) collect '&ign) ,ret-value)
	     ,@body))
       ,ret-value)))

(defun parse-string-w-regex (s regex)
  "returns a list of matching groups in S, based on REGEX"
  (coerce (ret-n 1 (scan-to-strings regex s)) 'list))

(defclass/std chess-move ()
  ((lan 
    from-square 
    to-square 
    promotionp 
    promotion-piece)))

(defun lan->chess-move (lan-move)
  "convert chess move from (UCI) long algebraic notation to chess-move object"
  (let+ (((from-square to-square promotion-piece)
	  (parse-string-w-regex lan-move +lan-move-regex+)))
    (make-instance 'chess-move
		   :lan lan-move
		   :from-square from-square
		   :to-square to-square
		   :promotionp (not (string= promotion-piece ""))
		   :promotion-piece promotion-piece)))

(defclass/std engine-server ()
  ((config 
    server-process
    input 
    output)))

(defclass/std engine-config ()
  ((name :std "stockfish")
   (path :std "stockfish") 
   (prompt :std ">> ")
   (debug-level :std 3)
   (debug-stream :std *standard-output*)
   (options :std `(("UCI_LimitStrength" t)
		   ("UCI_Elo" 2000)))))

(defun start-engine-server (&optional
			      (config (make-instance 'engine-config)))
  (let* ((process (launch-program (path config) :input :stream :output :stream))
	 (input (process-info-input process))
	 (output (process-info-output process)))
    (make-instance 'engine-server
		   :config config
		   :server-process process
		   :input input
		   :output output)))

(defun stop-engine-server (engine)
  (run-command "quit" engine)
  (wait-process (server-process engine)))

(defun get-engine-output-until-regex* (regex engine)
  (let* (line
	 foundp
	 eofp
	 (results
	  (loop
	     until (or (setf foundp (scan regex line))
		       (setf eofp (not (listen (output engine)))))
	     collect (setf line (read-line (output engine))))))
    (log-engine-msg line engine)
    (log-engine-msg foundp engine)
    (log-engine-msg eofp engine)
    (log-engine-msg results engine)
    (values
     line
     results 
     foundp
     eofp)))

(defun get-engine-output-until-regex (regex engine &optional (timeout 5000) (period 50))
  (let* (foundp
	 (max (/ timeout period))
	 line
	 (results (apply #'append
			 (loop
			    for n from 1 to max
			    until foundp
			    collect
			      (let+ (((&values inner-line results inner-foundp) (get-engine-output-until-regex* regex engine)))
				(setf foundp inner-foundp)
				(setf line inner-line)
				(when (not foundp)
				  (if (not (= n max))
				      (sleep (/ period 1000))
				      (error "timeout when reading for engine output")))
				results)))))
    (values
     line
     results 
     foundp)))

(defun run-command* (command engine)
  (with-slots (config input) engine 
    (log-engine-msg command engine 3)
    (write-line command input)
    (finish-output input)))

(defun readyp (engine)
  (run-command* "isready" engine)
  (get-engine-output-until-regex "readyok" engine)
  t)

(defun run-command (command engine)
  (when (readyp engine)
    (run-command* command engine)))

(defun uci-go (engine wtime btime inc)
  (run-command (format nil "go wtime ~a btime ~a winc ~a binc ~a"
		       wtime btime inc inc)
	       engine)
  (elt (parse-string-w-regex
	(get-engine-output-until-regex "^bestmove"
				       engine
				       7200000)
	+best-move-regex+)
       0))

(defun get-engine-move* (engine &optional (move-time 5000))
  (run-command (concatenate 'string "go movetime " (write-to-string move-time))
	       engine)
  (get-engine-output-until-regex "^bestmove"
				 engine
				 (+ move-time 500)))

(defun get-engine-move-lan (engine &optional (move-time 5000))
  (elt (parse-string-w-regex (get-engine-move* engine move-time)
			     +best-move-regex+)
       0))


(defun get-engine-move (engine &optional (move-time 5000))
  (lan->chess-move (get-engine-move-lan engine move-time)))

(defun initialize-position (engine)
  (run-command "ucinewgame" engine)
  (run-command "position startpos" engine))

(defun update-position (pos engine)
  (run-command (concatenate 'string "position fen " pos) engine))

(defun setup-position (pos engine)
  (run-command "ucinewgame" engine)
  (update-position pos engine))

(defun set-option (option value engine)
  (run-command (concatenate 'string
			    "setoption name "
			    option
			    " value "
			    (cond
			      ((equal t value)
			       "true")
			      ((equal nil value)
			       "false")
			      ((integerp value)
			       (write-to-string value))
			      (t value)))
	       engine))

(defun initialize-engine (engine)
  (run-command* "uci" engine)
  (get-engine-output-until-regex "^uciok$" engine)
  (loop for option in (options (config engine))
     do (set-option (car option) (cadr option) engine))
  (initialize-position engine))

(defun get-engine-move-pos (pos engine &optional (move-time 5000))
  (setup-position pos engine)
  (get-engine-move engine move-time))

(defun log-engine-msg (msg engine &optional (msg-level 3))
  (with-slots (prompt debug-level debug-stream) (config engine)
    (when nil ;(>= debug-level msg-level)
      (write-string prompt debug-stream)
      (write-string (format nil "~a" msg) debug-stream)
      (terpri debug-stream))))
