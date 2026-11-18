function D = pb_load()
%PB_LOAD Local numeric inputs only; no web service or external runtime.
here = fileparts(mfilename('fullpath'));
D = jsondecode(fileread(fullfile(here, 'data', 'model.json')));
end
