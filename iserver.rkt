#! /bin/sh
#| Hey Emacs, this is -*-scheme-*- code!
#$Id$
exec  racket -l errortrace --require "$0" --main -- ${1+"$@"}
|#

#lang racket

(require
 (except-in "incubot.rkt" main)
 (only-in "vars.rkt" *incubot-logger*)
 (only-in "log-parser.rkt" utterance-text))

(define (log fmt . args)
  (when (*incubot-logger*)
    (apply (*incubot-logger*) (string-append "incubot-server:" fmt) args)))

(provide make-incubot-server)
(define make-incubot-server
  (match-lambda
   [(? string? ifn)
    (with-handlers ([exn:fail:filesystem?
                     (lambda (e)
                       (log "Uh oh: ~a; using empty corpus" (exn-message e))
                       (make-incubot-server (make-corpus)))])
      (call-with-input-file ifn make-incubot-server))]
   [(? input-port? inp)
    (log "Reading log from ~a..." inp)
    (make-incubot-server
     (time
      (with-handlers ([exn? (lambda (e)
                              (log "Ooops: ~a~%" (exn-message e))
                              (lambda ignored #f))])

        (begin0
            (make-corpus-from-sexps inp 100000)
          (log "Reading log from ~a...done~%" inp)))))]
   [(? corpus? c)
    (let ([*to-server*   (make-channel)]
          [*from-server* (make-channel)])
      (define funcs-by-symbol
        (make-immutable-hash
         `((get .
                ,(lambda (inp c)
                   (channel-put *from-server* (incubot-sentence inp c))
                   c))
           (put .
                ,(lambda (sentence c)
                   (channel-put *from-server* #t)
                   (add-to-corpus sentence c))))))
      (thread
       (lambda ()
         (let loop ([c c])
           (match (channel-get *to-server*)
             [(cons symbol inp)
              (loop ((hash-ref funcs-by-symbol symbol) inp c))]))))

      (lambda (command-sym inp)
        (log "incubot ~a ~s" command-sym inp)
        (channel-put *to-server* (cons command-sym inp))
        (channel-get *from-server*)))]))

(provide main)
(define (main . args)
  (parameterize
      ([*incubot-logger* (curry fprintf (current-error-port))])
    (let ([s (make-incubot-server
              (open-input-string
               (string-append
                "#s(utterance \"2010-01-19T03:01:31Z\" \"offby1\" \"##cinema\" \"Let's make hamsters race\")"
                "\n"
                "#s(utterance \"2010-01-19T03:01:31Z\" \"offby1\" \"##cinema\" \"Gimme some dough\")")
               ))])
      (define (get input) (s 'get input))
      (define (put sentence) (s 'put sentence))

      (define (try input) (printf "~a => ~s~%" input (time (get input))))

      (try "Oh shit")
      (try "Oops, ate too much cookie dough")
      (try "OOPS, ATE TOO MUCH COOKIE DOUGH")
      (put "What is all this shit?")
      (try "hamsters")
      (try "Oh shit"))))