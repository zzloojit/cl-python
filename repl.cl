(in-package :python)


(defun goto-python-top-level ()
  (let ((r (find-restart 'return-python-toplevel)))
    (if r
	(invoke-restart r)
      (warn "There is no Python REPL running."))))

(setf (top-level:alias "ptl")
  #'goto-python-top-level)


(defun retry-repl-comp ()
  (let ((r (find-restart 'retry-repl-comp)))
    (if r
	(invoke-restart r)
      (warn "There is no Python REPL running."))))

(setf (top-level:alias "rc")
  #'retry-repl-comp)

(defun retry-repl-eval ()
  (let ((r (find-restart 'retry-repl-eval)))
    (if r
	(invoke-restart r)
      (warn "There is no Python REPL running."))))

(setf (top-level:alias "re")
  #'retry-repl-eval)

(defvar *repl-mod*)

(defun repl ()
  (labels ((print-cmds-1 (cmds)
	     (loop for (cmd expl) in cmds do (format t "  ~13A: ~A~%" cmd expl)))
	   (print-cmds ()
	     (format t "~%In the Python interpreter:~%")
	     (print-cmds-1 '((":help" "print (this) help")
			     (":q" "quit")))
	     (format t "~%In the Lisp debugger:~%")
	     (print-cmds-1 '((":ptl" "back to Python top level")
			     (":rt"  "retry the last, failed Python command")))
	     (format t "~%"))
	   
	   (eval-print-ast (ast mod)
	     (destructuring-bind (module-stmt suite) ast
	       (assert (eq module-stmt 'module-stmt))
	       (assert (eq (car suite) 'suite-stmt))

	       (let ((val (block :val
			    (loop
			      (with-simple-restart
				  (retry-repl-comp
				   "Retry the compilation of the REPL command [:rc]")
				(let ((helper-func
				       (compile nil `(lambda ()
						       (with-this-module-context (,mod)
							 ,suite)))))
				  (loop
				    (with-simple-restart
					(retry-repl-eval
					 "Retry the execution the compiled REPL command [:re]")
				      (return-from :val
					(funcall helper-func))))))))))
		 (when val
		   (format t "~A~%" val))))))
    
    (loop
	with *repl-mod* = (make-module)
	initially (format t "[CLPython -- type `:q' to quit, `:help' for help]~%")

	do (loop
	     (with-simple-restart (return-python-toplevel "Return to Python top level [:ptl]")
	       (loop with acc = ()
		   do (format t (if acc "... " ">>> "))
		      (let ((x (read-line)))
			(cond
			 
			 ((string= x ":help")        (print-cmds))
			 ((string= x ":q")           (return-from repl 'Bye))
			 
			 ((string= x "")
			  (let ((total (apply #'concatenate 'string (nreverse acc))))
			    (setf acc ())
			    (loop
			      (restart-case
				  (progn
				    (let ((ast (parse-python-string total)))
				      (eval-print-ast ast *repl-mod*)
				      (return)))
				(try-parse-again ()
				    :report "Parse string again into AST")
				(recompile-grammar ()
				    :report "Recompile grammar"
				  (compile-file "parsepython")
				  (load "parsepython"))))))
			 
			 (t (push (concatenate 'string x (string #\Newline))
				  acc)

			    ;; Try to parse; if that returns a "simple" AST
			    ;; (just inspecting the value of a variable), the
			    ;; input is complete and ther's no need to wait for
			    ;; an empty line.
			    
			    (let* ((total (apply #'concatenate 'string (reverse acc)))
				   (ast (ignore-errors (parse-python-string total))))
			      (when ast
				(destructuring-bind (module-stmt (suite-stmt items)) ast
				  (assert (eq module-stmt 'module-stmt))
				  (assert (eq suite-stmt 'suite-stmt))
				  (when (and (= (length items) 1)
					     (listp (car items))
					     (not (member (caar items)
							  '(try-except-stmt try-finally-stmt
							    for-in-stmt funcdef-stmt classdef-stmt
							    if-stmt while-stmt)))))
				  (eval-print-ast ast *repl-mod*)
				  (setf acc nil)))))))))))))