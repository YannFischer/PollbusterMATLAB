function [model, report] = pb_importCatalogue(model, D, filename)
    %PB_IMPORTCATALOGUE Importe le catalogue JSON extrait du site.
    %
    % Utilisation :
    %   [model, report] = pb_importCatalogue(model, D, filename)
    %
    % Comportement :
    %   - ne duplique pas les candidats natifs identifies par builtin ;
    %   - ignore les candidats deja importes ;
    %   - ajoute les autres candidats inactifs ;
    %   - conserve zone, noto et fams du catalogue ;
    %   - cree un identifiant de famille technique catalogue_* ;
    %   - initialise les positions au centre de la zone ;
    %   - ne donne aucune voix propres a cette famille technique.
    %
    % Cette fonction importe les estimations du catalogue. Elle ne porte
    % pas toute la logique web de reconstruction des criteres de notoriete.

    arguments
        model (1, 1) struct
        D (1, 1) struct
        filename (1, :) char
    end

    assert(isfile(filename), ...
        'Pollbuster:CatalogueNotFound', ...
        'Catalogue introuvable : %s', filename);

    decoded = jsondecode(fileread(filename));
    entries = pb_cells(decoded);

    assert(~isempty(entries), ...
        'Pollbuster:EmptyCatalogue', ...
    'Le catalogue est vide.');

    assert(~isempty(model.candidates), ...
        'Pollbuster:EmptyCandidateTemplate', ...
    'Un catalogue initial de candidats est necessaire.');

    % Le gabarit garantit les memes champs que les candidats existants.
    template = model.candidates(1);

    report = struct( ...
        'added', 0, ...
        'builtin', 0, ...
        'existing', 0, ...
        'ids', {{}});

    historicalReservoirs = pb_build2027(D, model.cfg);
    historicalFamilies = {historicalReservoirs.id};

    for index = 1:numel(entries)
        entry = entries{index};

        assert(isstruct(entry) && isscalar(entry), ...
            'Pollbuster:InvalidCatalogueEntry', ...
            'Entree %d : objet JSON attendu.', index);

        key = requiredText(entry, 'key', index);
        name = requiredText(entry, 'nom', index);

        %% Candidat deja fourni par le moteur

        builtin = pb_get(entry, 'builtin', '');

        if ~isempty(builtin)
            builtin = char(builtin);

            assert(any(strcmp({model.candidates.id}, builtin)), ...
                'Pollbuster:MissingBuiltinCandidate', ...
                ['Le catalogue reference le candidat natif "%s", ' ...
                 'absent du scenario. Repartir du catalogue initial ' ...
             'avant cet import.'], builtin);

            report.builtin = report.builtin + 1;
            continue
        end

        %% Identifiants stables

        assert(isvarname(key), ...
            'Pollbuster:InvalidCatalogueKey', ...
            'Cle de catalogue invalide : %s', key);

        candidateId = ['cat_' key];
        familyId = ['catalogue_' key];

        assert(isvarname(candidateId) && isvarname(familyId), ...
            'Pollbuster:InvalidGeneratedId', ...
            'Identifiant genere invalide pour : %s', key);

        if any(strcmp({model.candidates.id}, candidateId))
            report.existing = report.existing + 1;
            continue
        end

        %% Zone politique

        zoneId = requiredText(entry, 'zone', index);

        zoneIndex = find( ...
            strcmp({D.core.zones.id}, zoneId), 1);

        assert(~isempty(zoneIndex) ...
            && ~strcmp(zoneId, 'Z0') ...
            && isfield(D.colors, zoneId), ...
            'Pollbuster:InvalidCatalogueZone', ...
            'Zone politique invalide pour %s : %s', name, zoneId);

        position = D.core.zones(zoneIndex).mu;
        position = position(:)';

        %% Notoriete estimee du catalogue

        notoriety = pb_get(entry, 'noto', []);

        assert(isnumeric(notoriety) ...
            && isscalar(notoriety) ...
            && isreal(notoriety) ...
            && isfinite(notoriety) ...
            && notoriety >= 0 ...
            && notoriety <= 1, ...
            'Pollbuster:InvalidCatalogueNotoriety', ...
            'Notoriete invalide pour %s.', name);

        %% Famille principale et familles supplementaires
        families = pb_cells(pb_get(entry, 'fams', {}));
        families = families(:)';

        for familyIndex = 1:numel(families)
            family = families{familyIndex};
            assert(ischar(family) ...
                && any(strcmp(historicalFamilies, family)), ...
                'Pollbuster:UnknownCatalogueFamily', ...
                'Famille inconnue pour %s.', name);
        end

        [mainFamily, additionalFamilies] = chooseFam(families, familyId);
        additionalFamilies = unique(additionalFamilies, 'stable');

        %% Construction du candidat

        candidate = template;

        candidate.id = candidateId;
        candidate.name = name;

        candidate.zone = zoneId;
        candidate.by_hist = position;
        candidate.pos = [];

        candidate.fam = mainFamily;
        candidate.fams = additionalFamilies;

        candidate.noto = notoriety;
        candidate.force = 1;
        candidate.meme = false;

        % La notoriete est explicite : led ne sert pas ici a la recalculer.
        % Les valeurs historiques brutes restent conservees dans le JSON.
        candidate.led = 0;

        model.candidates(end + 1, 1) = candidate;
        model.active(end + 1, 1) = false;

        %% Profil thematique des candidats supplementaires

        % Le code web utilise O_DEFAULT.of pour les candidats ajoutes.
        % Reprendre ce profil lorsqu'il existe.
        if isfield(D.themes.O_DEFAULT, 'of')
            themeProfile = D.themes.O_DEFAULT.of;
        else
            % Repli explicite : profil uniforme, non observe.
            themeKeys = fieldnames(model.cfg.salience);
            themeProfile = struct();

            for themeIndex = 1:numel(themeKeys)
                themeProfile.(themeKeys{themeIndex}) = 0.5;
            end

        end

        model.cfg.themeProfiles.(candidateId) = themeProfile;

        %% Continuite avec le pouvoir sortant

        if ~isfield(model.cfg.options, 'cont')
            model.cfg.options.cont = struct();
        end

        model.cfg.options.cont.(candidateId) = 0;

        %% Rapport

        report.added = report.added + 1;
        report.ids{end + 1, 1} = candidateId;
    end

end

function value = requiredText(entry, field, index)
    %REQUIREDTEXT Lecture d'un champ texte obligatoire.

    assert(isfield(entry, field), ...
        'Pollbuster:MissingCatalogueField', ...
        'Entree %d : champ "%s" manquant.', index, field);

    value = entry.(field);

    if isstring(value) && isscalar(value)
        value = char(value);
    end

    assert(ischar(value) ...
        && isrow(value) ...
        && ~isempty(strtrim(value)), ...
        'Pollbuster:InvalidCatalogueText', ...
        'Entree %d : champ "%s" invalide.', index, field);

    value = strtrim(value);
end

function [chosenFam, additionalFams] = chooseFam(fams, fallbackFamily)
    if isempty(fams)
        chosenFam = fallbackFamily;
        additionalFams = {};
    else
        chosenFam = fams{1};
        additionalFams = fams(2:end);
    end
end
