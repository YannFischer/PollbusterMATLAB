function rs = pb_build2027(D, cfg)
    %PB_BUILD2027 Native reconstruction of 2022/2024 reservoirs, in million votes.
    S = cfg.build;
    X = D.scenario;
    rs = repmat(emptyRes(), 0, 1);
    death = struct('mel', .035, ...
        'rou', .065, ...
        'jad', .04, ...
        'hid', .08, ...
        'mac', .075, ...
        'pec', .09, ...
        'lep', .05, ...
        'zem', .06, ...
        'nda', .06, ...
        'las', .07, ...
        'pou', .03, ...
        'art', .04);
    lists = pb_cells(X.lists);
    names = fieldnames(X.transitions);
    rerun = struct('mel', 1, ...
        'rou', 1, ...
        'jad', 0, ...
        'hid', 0, ...
        'mac', 0, ...
        'pec', 0, ...
        'lep', 1, ...
        'zem', 1, ...
        'nda', 1, ...
        'las', 0);
    % Reservoir 'rn' (electorat RN-Bardella 2024), optionnel : cfg.bardella.enabled.
    bardellaCfg = pb_get(cfg, 'bardella', struct());
    bardellaOn = pb_get(bardellaCfg, 'enabled', false);

    for ii = 1:numel(names)
        id = names{ii};
        k = ensure(id, X.famzones.(id));
        n = X.votes22.(id) * (1 - death.(id));
        r = X.part24.(id);
        a = X.transitions.(id);
        a = a(:)';
        own = pb_cells(X.own.(id));
        q = max(0, (S.P_RET - r) / (1 - r)); owned = 0;

        for j = 1:numel(lists)

            if any(strcmp(own, lists{j}))
                owned = owned + a(j);
            end

        end

        owned = owned / sum(a);

        for j = 1:numel(lists)
            lid = lists{j};
            mass = n * r * a(j) / sum(a);

            if any(strcmp(own, lid))
                rs(k).fid = rs(k).fid + mass;
            else
                z = pb_get(X.listzones, lid, '');

                if isempty(z)
                    z = X.famzones.(id);
                end

                rs(k).flot = addField(rs(k).flot, z, mass);
            end

        end

        if ischar(S.LOYAL)
            loyal = rerun.(id);
        else
            loyal = S.LOYAL;
        end

        u = n * (1 - r) * q;
        g = u * (loyal + (1 - loyal) * owned);
        rs(k).fid = rs(k).fid + g;
        rs(k).fidP = rs(k).fidP + g;

        for j = 1:numel(lists)
            lid = lists{j};

            if any(strcmp(own, lid))
                continue
            end

            z = pb_get(X.listzones, lid, '');

            if isempty(z)
                z = X.famzones.(id);
            end

            rs(k).flot = addField(rs(k).flot, z, u * (1 - loyal) * a(j) / sum(a));
        end

    end

    for cc = {'pou', 'art'}
        id = cc{1};
        k = ensure(id, 'Z1');
        rs(k).fid = X.votes22.(id) * (1 - death.(id)) * S.P_RET;
        rs(k).fidP = rs(k).fid;
    end

    k = ensure('new', 'Z0');
    distribution = [31 4 10 5 8 6 26 2 8];
    den = 0;

    for j = 1:numel(lists)

        if ~isempty(pb_get(X.listzones, lists{j}, ''))
            den = den + distribution(j);
        end

    end

    for j = 1:numel(lists)
        z = pb_get(X.listzones, lists{j}, '');

        if ~isempty(z)
            rs(k).flot = addField(rs(k).flot, z, 2.1 * distribution(j) / den);
        end

    end

    pull('Z4', 'pp', true);
    pull('Z5', 'ecolo', true);
    pull('Z3', 'pcf', true);

    % Meme construction que pp, ecolo et pcf : tout ce qui flotte dans Z11 (electeurs
    % d'autres familles ayant vote RN en 2024) forme un reservoir 'rn' distinct, avec
    % fid = masse, fidP = 0 et orig = familles d'origine. 'lep' garde alors seulement
    % ses propres electeurs.
    if bardellaOn
        pull('Z11', 'rn', true);
    end

    ensure('dv', 'Z8');

    if S.SOCLE24

        for pair = {'Z2', 'mel'; 'Z7', 'mac'; 'Z9', 'pec'; 'Z11', 'lep'; 'Z12', 'zem'}'
            pull(pair{1}, pair{2}, false);
        end

    end

    % Reservoir RN-Bardella 'rn' (optionnel, desactive par defaut).
    % Le reservoir RN 'lep' est scinde en deux :
    %   - 'lep' : noyau historique (electeurs Le Pen 2022 restes RN) ;
    %   - 'rn' : electeurs d'autres familles (Macron, Pecresse, Zemmour, ...) venus
    %             au RN en 2024, plus eventuellement une part du noyau (baseShare).
    % Une fraction de 'rn' est flottante dans Z12 (Zemmour), Z9 (LR et Lisnard) et
    % Z8 (centre droit) : il est donc plus permeable que 'lep'. Masse totale conservee.
    % Exemple :
    %   cfg.bardella = struct('enabled', true, 'baseShare', 0, 'defaultShare', 1, ...
    %       'origShare', struct('zem', 1), ...
    %       'leak', struct('Z12', .25, 'Z9', .20, 'Z8', .05));
    % Pour que Le Pen/Bardella puisse heriter de 'rn', pb_simulate ajoute 'rn'
    % aux familles des candidats de la famille 'lep'.
    B = pb_get(cfg, 'bardella', struct());

    if pb_get(B, 'enabled', false)
        kl = find(strcmp({rs.id}, 'lep'), 1);

        if ~isempty(kl)
            kb = ensure('rn', 'Z11');
            origShare = pb_get(B, 'origShare', struct());
            defaultShare = pb_get(B, 'defaultShare', 1);
            baseShare = min(1, max(0, pb_get(B, 'baseShare', 0)));
            oids = fieldnames(rs(kl).orig);

            for jj = 1:numel(oids)
                oid = oids{jj};
                m0 = rs(kl).orig.(oid);
                m = m0 * min(1, max(0, pb_get(origShare, oid, defaultShare)));
                rs(kl).orig.(oid) = m0 - m;
                rs(kl).fid = rs(kl).fid - m;
                rs(kb).orig = addField(rs(kb).orig, oid, m);
                rs(kb).fid = rs(kb).fid + m;
            end

            origLeft = 0;
            oids = fieldnames(rs(kl).orig);

            for jj = 1:numel(oids)
                origLeft = origLeft + rs(kl).orig.(oids{jj});
            end

            baseMass = max(0, rs(kl).fid - rs(kl).fidP - origLeft);
            mb = baseShare * baseMass;
            rs(kl).fid = rs(kl).fid - mb;
            rs(kb).fid = rs(kb).fid + mb;

            leak = pb_get(B, 'leak', struct('Z12', 0.25, 'Z9', 0.20, 'Z8', 0.05));
            leakZones = fieldnames(leak);
            leakShare = zeros(1, numel(leakZones));

        for jj = 1:numel(leakZones)
            leakShare(jj) = min(1, max(0, leak.(leakZones{jj})));
        end

        if sum(leakShare) > 1
            leakShare = leakShare / sum(leakShare);
        end

        total = rs(kr).fid;

        for jj = 1:numel(leakZones)
            rs(kr).flot = addField(rs(kr).flot, leakZones{jj}, total * leakShare(jj));
        end

        keep = 1 - sum(leakShare);
        rs(kr).fid = total * keep;
        oids = fieldnames(rs(kr).orig);

        for jj = 1:numel(oids)
            rs(kr).orig.(oids{jj}) = rs(kr).orig.(oids{jj}) * keep;
        end

    end

    for j = 1:numel(rs)
        ov = pb_get(cfg.reservoirOverrides, rs(j).id, struct());
        scale = pb_get(ov, 'scale', 1);
        rs(j).fid = rs(j).fid * scale;
        rs(j).fidP = rs(j).fidP * scale;

        for field = {'flot', 'orig'}, fs = fieldnames(rs(j).(field{1}));

            for k = 1:numel(fs)
                rs(j).(field{1}).(fs{k}) = rs(j).(field{1}).(fs{k}) * scale;
            end

        end

    end

    function k = ensure(id, z)
        k = find(strcmp({rs.id}, id), 1);

        if isempty(k)
            r0 = emptyRes();
            r0.id = id;
            r0.zone = z;
            rs(end + 1, 1) = r0;
            k = numel(rs);
        end

    end

    function pull(z, id, replace)
        mass = 0;
        orig = struct();

        for kk = 1:numel(rs)
            value = pb_get(rs(kk).flot, z, 0);

            if value ~= 0
                mass = mass + value;

                if replace || ~strcmp(rs(kk).id, id)
                    orig = addField(orig, rs(kk).id, value);
                end

                rs(kk).flot = rmfield(rs(kk).flot, z);
            end

        end

        kk = ensure(id, z);

        if replace
            rs(kk).fid = mass;
            rs(kk).fidP = 0;
            rs(kk).orig = orig;
            rs(kk).flot = struct();
        else
            rs(kk).fid = rs(kk).fid + mass;
            fs = fieldnames(orig);

            for jj = 1:numel(fs)
                rs(kk).orig = addField(rs(kk).orig, fs{jj}, orig.(fs{jj}));
            end

        end

    end

end

function r = emptyRes()
    r = struct('id', '', 'zone', '', 'fid', 0, 'fidP', 0, 'orig', struct(), 'flot', struct());
end

function s = addField(s, k, v)
    s.(k) = pb_get(s, k, 0) + v;
end
