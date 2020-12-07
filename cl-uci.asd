(asdf:defsystem :cl-uci
  :name "cl-uci"
  :depends-on (:cl-ppcre :alexandria :uiop :let-plus :defclass-std)
  :serial t
  :components
  ((:file "package")
   (:file "cl-uci")))
