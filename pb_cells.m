function c = pb_cells(x)
%PB_CELLS Normalize decoded JSON arrays without toolboxes.
if isempty(x), c = {}; elseif iscell(x), c = x; elseif isstruct(x), c = num2cell(x); elseif ischar(x), c = {x}; elseif isstring(x), c = cellstr(x); else, c = num2cell(x); end
c = c(:)';
end
