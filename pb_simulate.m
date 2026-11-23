function out = pb_simulate(D, cfg)
%PB_SIMULATE Public, GUI-independent simulation entry point.
if nargin < 1 || isempty(D), D = pb_load(); end
if nargin < 2 || isempty(cfg), cfg = pb_defaults(D); end

if strcmp(pb_get(cfg, 'mode', '2027'), '2027')
    allCandidates = pb_candidates(D, cfg);
    active = ismember({allCandidates.id}, pb_cells(cfg.active));
    cs = allCandidates(active);
    rs = pb_build2027(D, cfg);
    opt = cfg.options;

    if cfg.themesEnabled
        opt.themes = struct('S', cfg.salience, 'PI', D.themes.PI, 'O', cfg.themeProfiles, 'theta', cfg.themeTheta);
    elseif isfield(opt, 'themes')
        opt = rmfield(opt, 'themes');
    end

    force = pb_get(opt, 'force', struct());

    for j = 1:numel(cs)
        force.(cs(j).id) = cs(j).force;
    end

    opt.force = force;
    [cs, opt] = applyBardella(cs, opt, cfg);
else
    cs = cfg.input.candidates;
    rs = cfg.input.reservoirs;
    opt = cfg.input.options;
end

out = pb_engine(D, rs, cs, opt);
end

function [cs, opt] = applyBardella(cs, opt, cfg)
%APPLYBARDELLA Branche le reservoir 'bar' (cree par pb_build2027) au moteur.
% - ajoute 'bar' aux familles des candidats de la famille 'lep' (heritiers) ;
% - definit le profil social opt.prof.bar s'il n'existe pas deja.
% Profil : cfg.bardella.profile (struct par categorie) s'il est fourni, sinon le
% profil RN opt.prof.lep multiplie par cfg.bardella.profileTilt (hypothese de
% travail, non mesuree : defaut cad 1.3, PI 1.15, emp 0.95, ouv 0.9).
B = pb_get(cfg, 'bardella', struct());
if ~pb_get(B, 'enabled', false), return, end

for j = 1:numel(cs)

    if strcmp(cs(j).fam, 'lep')
        f = pb_cells(pb_get(cs(j), 'fams', {}));
        if ~any(strcmp(f, 'bar')), f = [f(:)', {'bar'}]; end
        cs(j).fams = f;
    end

end

prof = pb_get(opt, 'prof', struct());

if ~isfield(prof, 'bar')
    custom = pb_get(B, 'profile', []);

    if ~isempty(custom)
        barProfile = custom;
    else
        barProfile = pb_get(prof, 'lep', struct());
        tilt = pb_get(B, 'profileTilt', struct('cad', 1.3, 'PI', 1.15, 'emp', 0.95, 'ouv', 0.9));
        tiltFields = fieldnames(tilt);

        for k = 1:numel(tiltFields)
            key = tiltFields{k};
            if isfield(barProfile, key), barProfile.(key) = barProfile.(key) * tilt.(key); end
        end

    end

    prof.bar = barProfile;
    opt.prof = prof;
end

end
