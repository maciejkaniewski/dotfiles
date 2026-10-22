; extends

((binary_expression
  operator: _ @_op
  (#any-of? @_op "<<" ">>")) @shift.outer)

((assignment_expression
  operator: _ @_op
  (#any-of? @_op "<<=" ">>=")) @shift.outer)

((binary_expression
  left: (_) @shift.inner
  operator: _ @_op
  (#any-of? @_op "<<" ">>")))
