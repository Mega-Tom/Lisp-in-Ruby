(defun map (f l)
    (if l
        (cons (funcall f (car l)) (map f (cdr l)))
        nil
    )
)
(set +1 (lambda (x) (+ x 1)))
(write
    (map +1 (list 1 2 5))
)