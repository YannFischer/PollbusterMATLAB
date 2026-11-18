function value = pb_get(s, field, fallback)
%PB_GET Read an optional model field without changing zero/false values.
if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
    value = s.(field);
else
    value = fallback;
end

end
