function report = pb_selftest()
    %PB_SELFTEST Compare the native engine to frozen original V18 numeric outputs.
    % Tests are run in MATLAB, never by an external interpreter.
    D = pb_load();
    here = fileparts(mfilename('fullpath'));
    cases = pb_cells(jsondecode(fileread(fullfile(here, 'data', 'references.json'))));
    Case = {};
    MaxScoreError = [];
    MaxVoiceError = [];
    ConservationError = [];

    for k = 1:numel(cases)
        c = cases{k};
        r = pb_engine(D, c.input.reservoirs, c.input.candidates, c.input.options);
        record(c.name, r, c.expected);

        if isfield(c, 'nativeConfig')
            cfg = pb_defaults(D);
            q = c.nativeConfig;

            for field = {'candidateOverrides', 'reservoirOverrides', 'build'}

                if isfield(q, field{1}) && ~isempty(q.(field{1}))
                    cfg.(field{1}) = q.(field{1});
                end

            end

            r = pb_simulate(D, cfg); record([c.name ' + construction MATLAB'], r, c.expected);
        end

        if k <= 5
            cfg = pb_defaults(D);
            cfg.active = pb_cells(c.ids);
            allc = pb_candidates(D, cfg);
            allc = allc(ismember({allc.id}, cfg.active));
            rs = pb_build2027(D, cfg);
            opt = cfg.options;
            fields = fieldnames(c.overrides);

            for j = 1:numel(fields)
                opt.(fields{j}) = c.overrides.(fields{j});
            end

            r = pb_engine(D, rs, allc, opt);
            record([c.name ' + construction MATLAB'], r, c.expected);
        end

    end

    cfg = pb_defaults(D);
    r = pb_simulate(D, cfg);
    record('API publique H11', r, cases{1}.expected);
    report = table(Case, MaxScoreError, MaxVoiceError, ConservationError);
    disp(report);
    fprintf('%d cas valides ; aucun runtime externe utilise.\n', height(report));

    function record(name, r, expected)
        eScore = 0;
        eVoice = 0;

        for ii = 1:numel(r.ids)
            id = r.ids{ii};
            eScore = max(eScore, abs(r.pct(ii) - expected.pct.(id)));

            for gg = 1:numel(D.core.pcs)
                g = D.core.pcs(gg).id;
                eVoice = max(eVoice, abs(r.V(ii, gg) - expected.V.(id).(g)));
            end

        end

        assert(eScore < 1e-8, 'Pollbuster:ScoreMismatch', '%s : erreur de score %.12g point.', name, eScore);
        assert(eVoice < 1e-3, 'Pollbuster:VoiceMismatch', '%s : erreur de voix %.12g.', name, eVoice);
        assert(abs(r.E - expected.E) < 1e-3, 'Pollbuster:TotalMismatch', '%s : total different.', name);
        assert(abs(sum(r.pct) - 100) < 1e-9 && all(r.V(:) >= -1e-8), 'Scores ou voix invalides.');
        assert(abs(r.conservationError) < 1e-3, 'Conservation des reservoirs non respectee.');
        assert(max(abs(sum(r.sources, 1)' - r.T)) < 1e-3, 'Somme des origines incoherente.');
        assert(max(abs(sum(r.V, 2) - r.T)) < 1e-6, 'Somme sociale incoherente.');
        Case{end + 1, 1} = name;
        MaxScoreError(end + 1, 1) = eScore;
        MaxVoiceError(end + 1, 1) = eVoice;
        ConservationError(end + 1, 1) = r.conservationError;
    end

end
