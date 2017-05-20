-- Search for ruler with NumMarks and MaxLength
const NumMarks  = 6
const MaxLength = 17

-- Num bits needed to represent ruler
const N = MaxLength + 1

-- "Shift algorithm" due to Rankin & McCracken
var ruler : Bit<N>  = 1  -- Positions of marks on ruler
var dist  : Bit<N>  = 0  -- Distances measured by ruler
var marks : Bit<5>  = 1  -- Number of marks made so far

while marks /= NumMarks do
  if msb(ruler) == 1 then fail end ;
  if (ruler & dist) == 0 then
      (ruler := ruler << 1)
    ? (marks := marks + 1 ||
       dist  := dist | ruler ;
       ruler := (ruler << 1) | 1)
  else
    ruler := ruler << 1
  end
end


-- TODO:
--   * introduce 'remLen' variable, for remaining length
--   * fail when remLen becomes 0
--   * change marks to remMarks
--   * succeed when remMarks becomes 0
--   * add min array, such that min[n] gives optimal length for n marks
--   * fail if remLen < min[remMarks]