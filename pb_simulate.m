function out = pb_simulate(D, cfg)
%PB_SIMULATE Public, GUI-independent simulation entry point.
if nargin < 1 || isempty(D), D = pb_load(); end
if nargin < 2 || isempty(cfg), cfg = pb_defaults(D); end

if strcmp(pb_get(cfg, 'mode', '2027'), '2027')
    allCandidates = pb_candidates(D, cfg); active = ismember({allCandidates.id}, pb_cells(cfg.active));
    cs = allCandidates(active); rs = pb_build2027(D, cfg); opt = cfg.options;

    if cfg.themesEnabled
        opt.themes = struct('S', cfg.salience, 'PI', D.themes.PI, 'O', cfg.themeProfiles, 'theta', cfg.themeTheta);
    elseif isfield(opt, 'themes'), opt = rmfield(opt, 'themes'); end
        force = pb_get(opt, 'force', struct()); for j = 1:numel(cs), force.(cs(j).id) = cs(j).force; end, opt.force = force;
    else
        cs = cfg.input.candidates; rs = cfg.input.reservoirs; opt = cfg.input.options;
    end

    out = pb_engine(D, rs, cs, opt);
end
