(defpackage #:cl-uci
  (:use #:cl #:let-plus #:cl-ppcre #:alexandria #:defclass-std)
  (:import-from #:uiop
                #:launch-program
                #:process-alive-p
                #:process-info-input
                #:process-info-output
                #:terminate-process
                #:wait-process)
  (:import-from #:uiop/launch-program
                #:process-info)
  (:export #:make-chess-move
	   #:lan->chess-move
	   #:make-engine-server
	   #:make-engine-config
	   #:initialize-engine
	   #:start-engine-server
	   #:stop-engine-server
	   #:get-engine-output-until-regex
	   #:run-command
	   #:readyp
	   #:setup-position
	   #:update-position
	   #:initialize-position
	   #:set-option
	   #:uci-go
	   #:get-engine-move 
	   #:get-engine-move-lan
	   #:get-engine-move-pos))
