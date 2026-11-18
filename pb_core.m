function [P, diag] = pb_core(D, cs, overrides)
%PB_CORE Native V18 attraction kernel (probabilities used by the reservoir engine).
% The unused legacy diagnostic score post-processing is deliberately omitted.
a = D.core.params; fs = fieldnames(overrides); for k = 1:numel(fs), a.(fs{k}) = overrides.(fs{k}); end
Z = D.core.zones; G = D.core.pcs; nc = numel(cs); ng = numel(G); nz = numel(Z) - 1;
xy = zeros(nc, 2); zi = zeros(nc, 1); noto = zeros(nc, 1); anchor = zeros(nc, 1); pos = zeros(ng, 2);
for g = 1:ng, point = D.core.pcspos.(G(g).id); pos(g, :) = point(:)'; end

for c = 1:nc
    zi(c) = find(strcmp({Z.id}, cs(c).zone), 1); pp = pb_get(cs(c), 'pos', pb_get(cs(c), 'by_hist', Z(zi(c)).mu)); xy(c, :) = pp(:)';
    noto(c) = cs(c).noto; anchor(c) = cs(c).ancrage;
end

penetration = zeros(nz + 1, ng);
for z = 1:nz + 1, for g = 1:ng, pair = D.core.hist.(Z(z).key).(G(g).id); penetration(z, g) = mean(pair); end, end
zmean = mean(penetration, 2); por = zeros(nz, nz);
for j = 1:nz, for k = 1:nz, por(j, k) = D.core.porosity.(Z(j + 1).id).(Z(k + 1).id); end, end
kernel = zeros(nc, ng);

for c = 1:nc
    sigma = Z(zi(c)).sigma * a.SIGMA_BOOST; detv = max(.01, sigma(1, 1) * sigma(2, 2) - sigma(1, 2) ^ 2);
    invs = [sigma(2, 2) -sigma(1, 2); -sigma(1, 2) sigma(1, 1)] / detv;
    for g = 1:ng, dd = pos(g, :) - xy(c, :); kernel(c, g) = exp(- .5 * max(0, dd * invs * dd')); end
end

ksum = max(.01, sum(kernel, 1)); occupation = zeros(nz, 1);

for z = 1:nz
    mu = Z(z + 1).mu(:)'; v = 0;
    for c = 1:nc, if zi(c) == 1, continue, end, v = v + exp(-sum((xy(c, :) - mu) .^ 2) / (2 * a.SIGMA_ORPHAN ^ 2)) * noto(c); end
    occupation(z) = min(1, v);
end

orphan = ones(nc, 1); rival = noto; blend = zeros(nc, nz); zpos = zi;

for c = 1:nc

    if zi(c) ~= 1
        num = 0; den = 0;

        for z = 1:nz
            if z + 1 == zi(c), continue, end
            w = exp(-sum((xy(c, :) - Z(z + 1).mu(:)') .^ 2) / (2 * a.SIGMA_ORPHAN ^ 2)) * Z(z + 1).masse / 100;
            num = num + w * (1 - occupation(z)); den = den + w;
        end

        ratio = 0; if den > .01, ratio = num / den; end
        orphan(c) = 1 + a.ORPHAN_MAX * min(1, ratio);

        for j = 1:nc
            if j == c || zi(j) == 1, continue, end
            rival(c) = max(rival(c), noto(j) * exp(-sum((xy(c, :) - xy(j, :)) .^ 2) / (2 * a.SIGMA_RIVAL ^ 2)));
        end

    end

    best = inf; bestzone = 2;

    for z = 1:nz
        dist = sum((xy(c, :) - Z(z + 1).mu(:)') .^ 2); blend(c, z) = exp(-dist / (2 * a.SIGMA_BLEND ^ 2)); factor = 1;

        if zi(c) ~= 1 && zi(c) ~= z + 1
            p1 = penetration(z + 1, :); p2 = penetration(zi(c), :); aa = p1 - mean(p1); bb = p2 - mean(p2); den = sum(aa .^ 2) * sum(bb .^ 2);
            correlation = 0; if den > 0, correlation = sum(aa .* bb) / sqrt(den); end
            penalty = max(0, -correlation) * a.ZP_PCS_NEG + max(0, .5 - max(0, correlation)) * a.ZP_PCS_LOW;
            x1 = Z(zi(c)).mu(1); x2 = Z(z + 1).mu(1); xpen = 0;

            if x1 * x2 < 0 && abs(x1 - x2) > a.ZP_X_SIGN, xpen = min(a.ZP_X_SIGN_MAX, abs(x1 - x2) * a.ZP_X_SIGN_K);
            elseif abs(x1 - x2) > a.ZP_X_FAR, xpen = (abs(x1 - x2) - a.ZP_X_FAR) * a.ZP_X_FAR_K; end
                wall = 0; if any(strcmp(pb_cells(pb_get(D.core.walls, cs(c).zone, {})), Z(z + 1).id)), wall = a.ZP_WALL; end
                factor = 1 + penalty + xpen + wall;
            end

            if dist * factor < best, best = dist * factor; bestzone = z + 1; end
        end

        if sum(blend(c, :)) > .001, blend(c, :) = blend(c, :) / sum(blend(c, :)); end
        moved = ~isempty(pb_get(cs(c), 'pos', [])) && ~isempty(pb_get(cs(c), 'by_hist', [])) && norm(cs(c).pos(:) - cs(c).by_hist(:)) > 1e-9;
        if zi(c) == 1, zpos(c) = 1; elseif moved || isempty(pb_get(cs(c), 'by_hist', [])), zpos(c) = bestzone; end
    end

    affinity = zeros(ng, nz);

    for g = 1:ng
        for z = 1:nz, affinity(g, z) = exp(-sum((pos(g, :) - Z(z + 1).mu(:)') .^ 2) / (2 * a.AFF_SIGMA ^ 2)); end
        affinity(g, :) = affinity(g, :) / sum(affinity(g, :));
    end

    raw = zeros(nc, ng); idf = zeros(nc, 1); drift = idf;

    for c = 1:nc
        sig = a.SIGMA_ID_MIN + (a.SIGMA_ID_MAX - a.SIGMA_ID_MIN) * noto(c) * anchor(c);
        dh = inf; if ~isempty(pb_get(cs(c), 'by_hist', [])), dh = sum((xy(c, :) - cs(c).by_hist(:)') .^ 2); end
        dz = sum((xy(c, :) - Z(zi(c)).mu(:)') .^ 2); distance = min(dh, dz); identity = exp(-distance / (2 * sig ^ 2));

        if zi(c) ~= 1 && zpos(c) ~= zi(c)

            if any(strcmp(pb_cells(pb_get(D.core.walls, cs(c).zone, {})), Z(zpos(c)).id)), identity = identity * a.IDF_WALL;
            else
                x1 = Z(zi(c)).mu(1); x2 = Z(zpos(c)).mu(1);

                if x1 * x2 < 0 && abs(x1 - x2) > a.IDF_SIGN_X, identity = identity * a.IDF_SIGN;
                elseif abs(x1 - x2) > a.IDF_FAR_X, identity = identity * a.IDF_FAR; end
                end

            end

            identity = max(a.ID_FLOOR, identity); idf(c) = identity; drift(c) = sqrt(distance);
            if zi(c) == 1, base = a.ABST_NOTO; else, base = max(a.NOTO_FLOOR, noto(c) * sqrt(anchor(c))); end
            ratio = 1; if rival(c) > 1e-6, ratio = noto(c) / rival(c); end
            strength = base * (a.BONUS_BASE + a.BONUS_RANGE * ratio);

            for g = 1:ng
                hist = penetration(zi(c), g);
                if zi(c) == 1, blended = hist; else, blended = sum(blend(c, :) .* (zmean(zi(c)) * penetration(2:end, g) ./ zmean(2:end))'); end
                social = (1 - a.GAMMA) * hist + a.GAMMA * blended;
                if (a.REL_FORCE || any(strcmp(pb_cells(pb_get(a, 'REL_FORCE_ZONES', {})), cs(c).zone))) && zi(c) ~= 1, social = 20 * social / zmean(zi(c)); end
                attraction = a.POS_FLOOR + a.POS_RANGE * kernel(c, g) / ksum(g); permeability = 1;

                if zi(c) ~= 1
                    allAffinity = affinity(g, :) * por; meanAffinity = mean(allAffinity); ratio = 1; if meanAffinity > .001, ratio = allAffinity(zi(c) - 1) / meanAffinity; end
                    permeability = 1 + a.POROSITY_AMP * (ratio - 1);
                end

                raw(c, g) = social * strength * identity * attraction * orphan(c) * permeability;
            end

        end

        powered = raw .^ a.ALPHA; den = sum(powered, 1); P = zeros(size(raw)); idx = den > 1e-10; P(:, idx) = powered(:, idx) ./ den(idx);
        diag = struct('raw', raw, 'idf', idf, 'drift', drift, 'zpos', zpos, 'params', a);
    end
