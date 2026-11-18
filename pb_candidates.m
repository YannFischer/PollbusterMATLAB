function cs = pb_candidates(D, cfg)
%PB_CANDIDATES Construct standard candidate records and native notoriety.
ids = pb_cells(D.scenario.all); cs = repmat(template(), 0, 1);

for i = 1:numel(ids)
    id = ids{i}; a = D.scenario.candidates.(id); c = template();
    f = fieldnames(c);
    for k = 1:numel(f), if isfield(a, f{k}), c.(f{k}) = a.(f{k}); end, end
    c.by_hist = c.by_hist(:)'; c.pos = pb_get(a, 'pos', []); c.pos = c.pos(:)';
    c.fams = pb_cells(c.fams); c.name = pb_get(D.names, id, id);
    criteria = D.notoriety.R.y2027.(id); w = cfg.weights; crit = pb_cells(D.notoriety.CRIT); q = 1;

    for k = 1:numel(crit)
        key = crit{k}; v = criteria.(key);
        if strcmp(key, 'led'), v = 1 - exp(-v / D.notoriety.NP.LED_SCALE); end
        q = q * (1 - min(.99, v)) ^ pb_get(w, key, 1);
    end

    c.noto = max(.2, 1 - q);
    ov = pb_get(cfg.candidateOverrides, id, struct()); f = fieldnames(ov);
    for k = 1:numel(f), c.(f{k}) = ov.(f{k}); end
    cs(end + 1, 1) = c; %#ok<AGROW>
end

end

function c = template()
c = struct('id', '', 'name', '', 'zone', '', 'by_hist', [0 0], 'pos', [], 'fam', '', 'fams', {{}}, 'led', 0, 'noto', .2, 'meme', false, 'force', 1);
end
