(defun mod (n d)
    (while (ordered d n) (set n (- n d)))
    n
)

(set i 1)
(while (ordered i 100)
    (write
        (if (mod i 3)
            (if (mod i 5) 
                i
                "buzz"
            )
            (if (mod i 5) 
                "fizz"
                "fizzbuzz"
            )
        )
    )
    (set i (+ i 1))
)