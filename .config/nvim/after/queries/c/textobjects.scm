; extends

; Bitshift expressions: 1 << 5, val >> n
((binary_expression
  operator: _ @_op
  (#any-of? @_op "<<" ">>")) @shift.outer)

; Bitshift compound assignments: x <<= 1, y >>= 2
((assignment_expression
  operator: _ @_op
  (#any-of? @_op "<<=" ">>=")) @shift.outer)

; Inner = the value being shifted (left side of <<, >>) or the shift amount
((binary_expression
  left: (_) @shift.inner
  operator: _ @_op
  (#any-of? @_op "<<" ">>")))
