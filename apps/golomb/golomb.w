-- Search for 10 mark ruler of max length 55
var list  : 55 = 0x40000000000000
var diffs : 55 = 0
var marks : 5  = 1

begin
  while 1 do
    if marks == 10 then halt end ;
    if (list & 1) == 1 then fail end ;

    list := list >> 1 ;
    if ((list << 1) & diffs) == 0 then
        skip
      ? (diffs := diffs | (list << 1) ;
         list := list | 0x40000000000000 ||
         marks := marks + 1)
    end
  end
end