(eval-when (compile)
  (error "This defsys file should be loaded interpreted, not compiled."))

(in-package :user)

;; (setf compiler::*compile-with-compilation-unit-override* nil)

(excl:defsystem :python
    (:default-pathname #.*load-pathname*)
  (:serial "package" (:parallel
		      (:serial "parser" "lexer")
		      "pyprint"
		      "walk"
		      "compiler"
		      "gener"
		      "repl"
		      (:serial "builtin-classes" "builtin-funcs" "exceptions" "builtin-types")))
  (:definitions "walk" "compiler") ;; COMPILER uses code walk macro
  )


(format t "~%;;To compile and load, execute these forms:~%~s~%~s~%"
	'(excl:compile-system :python)
	'(excl:load-system    :python))

(format t ";;To create a single fasl file, execute:~%~s~%~%"
	'(excl:concatenate-system :python "python.fasl"))
