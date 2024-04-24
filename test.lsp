(defun fib (n)
  (if (ordered n 1)
    n
    (+ (fib (- n 1)) (fib (- n 2)))
  )
)

(set n 0)

(while (ordered n 5)
    (write (concat "F_" n " = " (fib n)))
    (set n (+ n 1))
)

(defun sum (nums)
    (if nums
        (+ (car nums) (sum (cdr nums)))
        0
    )
)
(write (list 1 2 3 4))
(write (sum (list 1 2 3 4)))
(defun list-concat (a b)
    (if a
        (cons (car a) (list-concat (cdr a) b))
        b
    )
)
(write (list-concat (list 1 2 5) (list 3 4 6)))

(defun merge (a b)
    (if a
        (if b
            (if (ordered (car a) (car b))
                (cons (car a) (merge (cdr a) b))
                (cons (car b) (merge (cdr b) a))
            )
            a
        )
        b
    )
)
(write (merge (list 1 2 5 7) (list 3 4 6)))
