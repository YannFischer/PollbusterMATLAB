function app = pb_gui()
%PB_GUI Interface unique du simulateur Pollbuster.
%
% Lancement :
%   runPollbuster
%
% Organisation :
%   model        : scenario modifiable
%   committed    : dernier scenario calcule avec succes
%   result       : dernier resultat valide
%   H            : composants graphiques
%
% Les candidats sont conserves dans le scenario de l'interface.
% Le calcul reutilise pb_build2027 et pb_engine sans les dupliquer.
%
% Les valeurs complexes de la table de parametres utilisent la syntaxe
% JSON : [0.1,0.2], true, false, etc. Aucun eval/str2num n'est utilise.
%
% A tester dans MATLAB avant utilisation scientifique.

D = pb_load();

model = initialModel(D);
committed = model;

result = [];
resultData = D;

selectedRow = 1;
selectedId = '';
parameterPaths = {};

background = [0.95 0.95 0.93];

%% Fenetre et organisation

H.fig = figure( ...
    'Name', 'Pollbuster MATLAB', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'figure', ...
    'Color', background, ...
    'Units', 'normalized', ...
    'Position', [0.04 0.06 0.92 0.86]);
setappdata(H.fig, 'PollbusterBusy', false);

H.editTabs = uitabgroup( ...
    H.fig, ...
    'Units', 'normalized', ...
    'Position', [0.01 0.14 0.49 0.85]);

H.candidateTab = uitab( ...
    H.editTabs, 'Title', 'Candidats');

H.parameterTab = uitab( ...
    H.editTabs, 'Title', 'Parametres');

H.reservoirTab = uitab( ...
    H.editTabs, 'Title', 'Reservoirs');

H.viewTabs = uitabgroup( ...
    H.fig, ...
    'Units', 'normalized', ...
    'Position', [0.51 0.14 0.48 0.85]);

H.mapTab = uitab(H.viewTabs, 'Title', 'Carte');
H.scoreTab = uitab(H.viewTabs, 'Title', 'Scores');
H.sourceTab = uitab(H.viewTabs, 'Title', 'Origines');
H.socialTab = uitab(H.viewTabs, 'Title', 'Composition sociale');

%% Candidats

H.candidates = uitable( ...
    H.candidateTab, ...
    'Units', 'normalized', ...
    'Position', [0.015 0.22 0.97 0.76], ...
    'ColumnName', { ...
    'Actif', 'ID', 'Nom', 'Famille', 'Zone', ...
    'Notoriete', 'Force', 'Sortant', ...
    'Deplacer', 'X', 'Y'}, ...
    'ColumnEditable', [ ...
    true false true true true ...
    true true true true true true], ...
    'ColumnFormat', { ...
    'logical', 'char', 'char', 'char', 'char', ...
    'numeric', 'numeric', 'logical', ...
    'logical', 'numeric', 'numeric'}, ...
    'ColumnWidth', { ...
    45, 65, 125, 65, 50, 70, 60, 55, 65, 65, 65}, ...
    'RowName', [], ...
    'CellSelectionCallback', @selectCandidate, ...
    'CellEditCallback', @editCandidate);

button(H.candidateTab, ...
    'Ajouter par duplication', ...
    [0.015 0.145 0.47 0.055], @addCandidate);

button(H.candidateTab, ...
    'Supprimer', ...
    [0.515 0.145 0.47 0.055], @deleteCandidate);

button(H.candidateTab, ...
    'Champs avances du candidat', ...
    [0.015 0.075 0.97 0.055], @editCandidateDetails);

uicontrol( ...
    H.candidateTab, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.015 0.01 0.97 0.055], ...
    'HorizontalAlignment', 'left', ...
    'String', [ ...
    'X/Y : positions politiques, pas coordonnees sociales. ' ...
    'Un nouveau candidat herite du candidat selectionne.']);

%% Parametres : une table issue des structures du modele

uicontrol( ...
    H.parameterTab, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.925 0.18 0.045], ...
    'HorizontalAlignment', 'left', ...
    'String', 'Filtrer');

H.filter = uicontrol( ...
    H.parameterTab, ...
    'Style', 'edit', ...
    'Units', 'normalized', ...
    'Position', [0.20 0.925 0.78 0.05], ...
    'HorizontalAlignment', 'left', ...
    'Callback', @(~,~) syncParameters());

H.parameters = uitable( ...
    H.parameterTab, ...
    'Units', 'normalized', ...
    'Position', [0.02 0.12 0.96 0.78], ...
    'ColumnName', {'Parametre', 'Valeur', 'Utilite'}, ...
    'ColumnEditable', [false true false], ...
    'ColumnFormat', {'char', 'char', 'char'}, ...
    'ColumnWidth', {310 220 540}, ...
    'RowName', [], ...
    'CellEditCallback', @editParameter);

uicontrol( ...
    H.parameterTab, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.01 0.96 0.095], ...
    'HorizontalAlignment', 'left', ...
    'String', { ...
    'options.part : participation par categorie ; options.pb : noyau.' ...
    'themesEnabled active les themes ; themeProfiles contient les profils.' ...
    'Vecteurs/objets : syntaxe JSON. Les textes simples restent sans guillemets.'});

%% Reservoirs

H.reservoirs = uitable( ...
    H.reservoirTab, ...
    'Units', 'normalized', ...
    'Position', [0.02 0.12 0.96 0.86], ...
    'ColumnName', { ...
    'Famille', 'Zone', 'Fideles M', ...
    'Flottants M', 'Retour pres. M', 'Echelle'}, ...
    'ColumnEditable', [false false false false false true], ...
    'ColumnWidth', {80 55 85 85 95 70}, ...
    'RowName', [], ...
    'CellEditCallback', @editReservoir);

uicontrol( ...
    H.reservoirTab, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.02 0.01 0.96 0.09], ...
    'HorizontalAlignment', 'left', ...
    'String', { ...
    'Les masses sont reconstruites avec build.P_RET, build.LOYAL et build.SOCLE24.' ...
    'Echelle multiplie le reservoir, donc modifie la masse totale.'});

%% Vues

H.showPCS = uicontrol( ...
    H.mapTab, ...
    'Style', 'checkbox', ...
    'Units', 'normalized', ...
    'Position', [0.03 0.93 0.90 0.05], ...
    'String', 'Afficher les reperes sociaux', ...
    'Value', false, ...
    'Callback', @(~,~) redraw());

H.mapAxes = axes( ...
    'Parent', H.mapTab, ...
    'Units', 'normalized', ...
    'Position', [0.10 0.13 0.84 0.73]);

H.scores = uitable( ...
    H.scoreTab, ...
    'Units', 'normalized', ...
    'Position', [0.02 0.02 0.96 0.96], ...
    'ColumnName', {'Candidat', 'Score %', 'Voix'}, ...
    'ColumnFormat', {'char', 'numeric', 'char'}, ...
    'ColumnWidth', {180 100 130}, ...
    'RowName', []);

H.selector = uicontrol( ...
    H.sourceTab, ...
    'Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.04 0.92 0.92 0.055], ...
    'String', {'Initialisation'}, ...
    'Callback', @changeDetailedCandidate);

H.sourceAxes = axes( ...
    'Parent', H.sourceTab, ...
    'Units', 'normalized', ...
    'Position', [0.24 0.15 0.70 0.70]);

H.socialAxes = axes( ...
    'Parent', H.socialTab, ...
    'Units', 'normalized', ...
    'Position', [0.24 0.15 0.70 0.72]);

%% Commandes

button(H.fig, 'Recalculer', ...
    [0.01 0.075 0.15 0.045], @recalculate);

button(H.fig, 'Sauver scenario', ...
    [0.175 0.075 0.15 0.045], @saveScenario);

button(H.fig, 'Charger scenario', ...
    [0.34 0.075 0.15 0.045], @loadScenario);

button(H.fig, 'Exporter CSV', ...
    [0.505 0.075 0.15 0.045], @exportCSV);

button(H.fig, 'Reinitialiser', ...
    [0.67 0.075 0.15 0.045], @resetScenario);

button(H.fig, 'Tester moteur', ...
    [0.835 0.075 0.15 0.045], @testEngine);

H.status = uicontrol( ...
    H.fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.015 0.01 0.97 0.05], ...
    'HorizontalAlignment', 'left', ...
    'String', 'Initialisation...');

%% API compatible avec le principe de l'ancienne interface

app = struct();
app.Figure = H.fig;
app.Recalculate = @recalculate;
app.GetResult = @() getappdata(H.fig, 'PollbusterResult');
app.GetConfig = @() getappdata(H.fig, 'PollbusterConfig');

applyModel(model);

%% Calcul et validation transactionnels

    function success = applyModel(proposed)
        success = false;

        if ~isgraphics(H.fig)
            return
        end

        if getappdata(H.fig, 'PollbusterBusy')
            return
        end

        figureHandle = H.fig;

        setappdata(figureHandle, 'PollbusterBusy', true);

        cleanupGuard = onCleanup( ...
            @() releaseCalculationLock(figureHandle));

        set(figureHandle, 'Pointer', 'watch');

        try
            validateModel(proposed, D);

            reservoirs = pb_build2027(D, proposed.cfg);
            candidates = proposed.candidates(proposed.active);

            options = proposed.cfg.options;

            % Une seule source de verite pour la force des candidats.
            options.force = struct();

            for index = 1:numel(candidates)
                candidate = candidates(index);
                options.force.(candidate.id) = candidate.force;
            end

            if proposed.cfg.themesEnabled
                options.themes = struct( ...
                    'S', proposed.cfg.salience, ...
                    'PI', proposed.themeZoneWeights, ...
                    'O', proposed.cfg.themeProfiles, ...
                    'theta', proposed.cfg.themeTheta);
            elseif isfield(options, 'themes')
                options = rmfield(options, 'themes');
            end

            candidateResult = pb_engine( ...
                D, reservoirs, candidates, options);

            candidateResult = calibrateElectorate( ...
                candidateResult, proposed.electorate);

            validateOutput(candidateResult);

            % Les noms personnalises doivent aussi servir a la carte
            % et aux exports, qui consultent D.names.
            displayData = D;

            for index = 1:numel(proposed.candidates)
                candidate = proposed.candidates(index);
                displayData.names.(candidate.id) = candidate.name;
            end

            % Tester le rendu avant de publier le nouveau resultat.
            pb_drawmap( ...
                H.mapAxes, displayData, candidateResult, ...
                logical(get(H.showPCS, 'Value')));

            model = proposed;
            committed = proposed;

            result = candidateResult;
            resultData = displayData;

            syncControls();
            redraw();

            setappdata(H.fig, 'PollbusterResult', result);
            setappdata(H.fig, 'PollbusterConfig', model);

            setStatus(sprintf( ...
                ['%d candidats actifs | %.3f M de suffrages | ' ...
                'ecart de conservation : %.3g voix. ' ...
                'Simulation conditionnelle, pas une probabilite de victoire.'], ...
                numel(result.ids), result.E / 1e6, ...
                result.conservationError), false);

            success = true;

        catch err
            model = committed;

            try
                syncControls();

                if ~isempty(result)
                    redraw();
                end
            catch
                % Ne pas masquer l'erreur initiale par une erreur de rendu.
            end

            setStatus( ...
                ['Modification refusee : ' err.message], true);

            setappdata(H.fig, 'PollbusterLastError', err);
        end
    end

    function recalculate(varargin)
        applyModel(model);
    end

%% Synchronisation des tables

    function syncControls()
        candidates = model.candidates;
        rows = cell(numel(candidates), 11);

        for index = 1:numel(candidates)
            candidate = candidates(index);
            moved = ~isempty(candidate.pos);

            if moved
                position = candidate.pos;
            else
                position = candidate.by_hist;
            end

            rows(index,:) = { ...
                model.active(index), candidate.id, ...
                candidate.name, candidate.fam, candidate.zone, ...
                candidate.noto, candidate.force, ...
                logical(candidate.meme), moved, ...
                position(1), position(2)};
        end

        set(H.candidates, 'Data', rows);

        selectedRow = min( ...
            max(1, selectedRow), numel(candidates));

        syncParameters();
        syncReservoirs();
    end

    function syncParameters()
        settings = editableSettings(model);

        [paths, values] = flattenSettings(settings, {});

        filterText = lower(strtrim(get(H.filter, 'String')));

        names = cell(numel(paths), 1);
        descriptions = cell(numel(paths), 1);
        keep = true(numel(paths), 1);

        for index = 1:numel(paths)
            names{index} = strjoin(paths{index}, '.');

            descriptions{index} = parameterDescription( ...
                names{index});

            searchableText = lower([ ...
                names{index}, ' ', descriptions{index}]);

            if ~isempty(filterText)
                keep(index) = contains(searchableText, filterText);
            end
        end

        parameterPaths = paths(keep);

        set(H.parameters, 'Data', [ ...
            names(keep), values(keep), descriptions(keep)]);
    end

    function syncReservoirs()
        reservoirs = pb_build2027(D, model.cfg);
        rows = cell(numel(reservoirs), 6);

        for index = 1:numel(reservoirs)
            reservoir = reservoirs(index);

            floating = structTotal(reservoir.flot);

            override = pb_get( ...
                model.cfg.reservoirOverrides, ...
                reservoir.id, struct());

            scale = pb_get(override, 'scale', 1);

            rows(index,:) = { ...
                reservoir.id, reservoir.zone, ...
                reservoir.fid, floating, reservoir.fidP, scale};
        end

        set(H.reservoirs, 'Data', rows);
    end

%% Edition des candidats

    function selectCandidate(~, event)
        if ~isempty(event.Indices)
            selectedRow = event.Indices(1,1);
        end
    end

    function editCandidate(~, event)
        if ~isgraphics(H.fig)
            return
        end

        if getappdata(H.fig, 'PollbusterBusy')
            return
        end

        proposed = model;

        row = event.Indices(1);
        column = event.Indices(2);
        value = event.NewData;

        candidate = proposed.candidates(row);

        switch column
            case 1
                proposed.active(row) = logical(value);

            case 3
                candidate.name = strtrim(char(value));

            case 4
                candidate.fam = strtrim(char(value));

            case 5
                candidate.zone = strtrim(char(value));

            case 6
                candidate.noto = value;

            case 7
                candidate.force = value;

            case 8
                candidate.meme = logical(value);

            case 9
                if value
                    candidate.pos = candidate.by_hist;
                else
                    candidate.pos = [];
                end

            case {10, 11}
                if isempty(candidate.pos)
                    syncControls();
                    setStatus( ...
                        'Cocher Deplacer avant de modifier X ou Y.', true);
                    return
                end

                candidate.pos(column - 9) = value;
        end

        proposed.candidates(row) = candidate;
        applyModel(proposed);
    end

    function addCandidate(varargin)
        source = model.candidates(selectedRow);

        answer = inputdlg( ...
            {'Identifiant unique', 'Nom du candidat'}, ...
            'Ajouter un candidat', 1, ...
            {uniqueCandidateId(model), 'Nouveau candidat'});

        if isempty(answer)
            return
        end

        id = strtrim(answer{1});
        name = strtrim(answer{2});

        if ~isvarname(id) || strcmp(id, 'abst')
            errordlg( ...
                'Utiliser un identifiant MATLAB valide, distinct de abst.', ...
                'Identifiant invalide');
            return
        end

        if any(strcmp({model.candidates.id}, id))
            errordlg('Cet identifiant existe deja.', 'Identifiant invalide');
            return
        end

        if isempty(name)
            errordlg('Le nom ne peut pas etre vide.', 'Nom invalide');
            return
        end

        proposed = model;

        candidate = source;
        candidate.id = id;
        candidate.name = name;

        % Une duplication ne transforme pas un nouveau candidat
        % en ancien candidat de sa famille.
        candidate.meme = false;

        proposed.candidates(end + 1, 1) = candidate;
        proposed.active(end + 1, 1) = true;

        profiles = proposed.cfg.themeProfiles;

        profiles.(id) = pb_get( ...
            profiles, source.id, struct());

        proposed.cfg.themeProfiles = profiles;

        continuity = pb_get( ...
            proposed.cfg.options, 'cont', struct());

        continuity.(id) = pb_get(continuity, source.id, 0);
        proposed.cfg.options.cont = continuity;

        if applyModel(proposed)
            selectedRow = numel(model.candidates);
        end
    end

    function deleteCandidate(varargin)
        if numel(model.candidates) <= 1
            errordlg( ...
                'Conserver au moins un candidat dans le catalogue.', ...
                'Suppression impossible');
            return
        end

        candidate = model.candidates(selectedRow);

        answer = questdlg( ...
            ['Supprimer ' candidate.name ' du scenario ?'], ...
            'Supprimer un candidat', ...
            'Supprimer', 'Annuler', 'Annuler');

        if ~strcmp(answer, 'Supprimer')
            return
        end

        proposed = model;

        proposed.candidates(selectedRow) = [];
        proposed.active(selectedRow) = [];

        if isfield(proposed.cfg.themeProfiles, candidate.id)
            proposed.cfg.themeProfiles = rmfield( ...
                proposed.cfg.themeProfiles, candidate.id);
        end

        if isfield(proposed.cfg.options, 'cont') ...
                && isfield(proposed.cfg.options.cont, candidate.id)
            proposed.cfg.options.cont = rmfield( ...
                proposed.cfg.options.cont, candidate.id);
        end

        applyModel(proposed);
    end

    function editCandidateDetails(varargin)
        candidate = model.candidates(selectedRow);

        answer = inputdlg( ...
            { ...
            'Position historique [x,y]', ...
            'Familles supplementaires : ["mel","pcf"] ou []', ...
            'Led : masse historique utilisee par le modele'}, ...
            ['Champs avances : ' candidate.name], ...
            [1 75; 2 75; 1 75], ...
            { ...
            jsonencode(candidate.by_hist), ...
            jsonencode(candidate.fams), ...
            jsonencode(candidate.led)});

        if isempty(answer)
            return
        end

        try
            candidate.by_hist = jsondecode(answer{1});
            candidate.by_hist = candidate.by_hist(:)';

            candidate.fams = pb_cells(jsondecode(answer{2}));
            candidate.led = jsondecode(answer{3});

            proposed = model;
            proposed.candidates(selectedRow) = candidate;

            applyModel(proposed);

        catch err
            errordlg(err.message, 'Valeur invalide');
        end
    end

%% Edition des parametres et reservoirs

    function editParameter(~, event)
        if ~isgraphics(H.fig)
            return
        end

        if getappdata(H.fig, 'PollbusterBusy')
            return
        end

        try
            path = parameterPaths{event.Indices(1)};

            settings = editableSettings(model);
            previous = getNested(settings, path);

            value = decodeValue(event.NewData, previous);

            settings = setNested(settings, path, value);

            proposed = model;

            proposed.electorate = settings.electorate;
            proposed.cfg.options = settings.options;
            proposed.cfg.build = settings.build;
            proposed.cfg.themesEnabled = settings.themesEnabled;
            proposed.cfg.salience = settings.salience;
            proposed.cfg.themeTheta = settings.themeTheta;
            proposed.cfg.themeProfiles = settings.themeProfiles;
            proposed.themeZoneWeights = settings.themeZoneWeights;

            applyModel(proposed);

        catch err
            syncParameters();
            setStatus(['Valeur refusee : ' err.message], true);
        end
    end

    function editReservoir(~, event)
        rows = get(H.reservoirs, 'Data');
        id = rows{event.Indices(1), 1};
        value = event.NewData;

        if ~isnumeric(value) || ~isscalar(value) ...
                || ~isfinite(value) || value < 0
            syncReservoirs();
            setStatus('Echelle attendue : nombre positif ou nul.', true);
            return
        end

        proposed = model;

        override = pb_get( ...
            proposed.cfg.reservoirOverrides, id, struct());

        override.scale = value;
        proposed.cfg.reservoirOverrides.(id) = override;

        applyModel(proposed);
    end

%% Resultats

    function redraw()
        if isempty(result)
            return
        end

        pb_drawmap( ...
            H.mapAxes, resultData, result, ...
            logical(get(H.showPCS, 'Value')));

        [~, order] = sort(result.pct, 'descend');
        rows = cell(numel(order), 3);
        names = cell(1, numel(result.ids));

        for index = 1:numel(result.ids)
            names{index} = result.candidates{index}.name;
        end

        for index = 1:numel(order)
            candidateIndex = order(index);

            rows(index,:) = { ...
                names{candidateIndex}, ...
                result.pct(candidateIndex), ...
                formatVotes(result.T(candidateIndex))};
        end

        set(H.scores, 'Data', rows);

        selection = find(strcmp(result.ids, selectedId), 1);

        if isempty(selection)
            selection = 1;
        end

        selectedId = result.ids{selection};

        set(H.selector, ...
            'String', names, ...
            'Value', selection);

        drawDetails(selection);
    end

    function changeDetailedCandidate(varargin)
        if isempty(result)
            return
        end

        index = get(H.selector, 'Value');
        selectedId = result.ids{index};

        drawDetails(index);
    end

    function drawDetails(index)
        candidate = result.candidates{index};

        sourceNames = cellfun( ...
            @(reservoir) reservoir.id, ...
            result.reservoirs, ...
            'UniformOutput', false);

        barh(H.sourceAxes, result.sources(:,index) / 1e6);

        set(H.sourceAxes, ...
            'YTick', 1:numel(sourceNames), ...
            'YTickLabel', sourceNames, ...
            'TickLabelInterpreter', 'none');

        xlabel(H.sourceAxes, 'Millions de voix');
        title(H.sourceAxes, candidate.name, 'Interpreter', 'none');
        grid(H.sourceAxes, 'on');

        total = sum(result.V(index,:));

        if total > 0
            shares = 100 * result.V(index,:) / total;
        else
            shares = zeros(1, size(result.V, 2));
        end

        barh(H.socialAxes, shares);

        set(H.socialAxes, ...
            'YTick', 1:numel(D.core.pcs), ...
            'YTickLabel', {D.core.pcs.id}, ...
            'TickLabelInterpreter', 'none');

        xlabel(H.socialAxes, 'Part de l''electorat du candidat (%)');
        title(H.socialAxes, candidate.name, 'Interpreter', 'none');
        grid(H.socialAxes, 'on');
    end

%% Fichiers et outils

    function saveScenario(varargin)
        [name, folder] = uiputfile('*.mat', 'Sauver le scenario');

        if isequal(name, 0)
            return
        end

        scenario = committed;
        scenarioVersion = 2;

        try
            save(fullfile(folder, name), ...
                'scenario', 'scenarioVersion');

            setStatus('Scenario sauvegarde.', false);

        catch err
            setStatus(err.message, true);
        end
    end

    function loadScenario(varargin)
        [name, folder] = uigetfile('*.mat', 'Charger un scenario');

        if isequal(name, 0)
            return
        end

        try
            loaded = load( ...
                fullfile(folder, name), ...
                'scenario', 'scenarioVersion', 'cfg');

            if isfield(loaded, 'scenario') ...
                    && isfield(loaded, 'scenarioVersion') ...
                    && isequal(loaded.scenarioVersion, 2)

                proposed = loaded.scenario;

            elseif isfield(loaded, 'cfg')
                % Import des anciens scenarios qui enregistrent cfg.
                proposed = initialModel(D);
                proposed.cfg = loaded.cfg;

                proposed.candidates = pb_candidates(D, loaded.cfg);
                proposed.active = ismember( ...
                    {proposed.candidates.id}', ...
                    pb_cells(loaded.cfg.active));
            else
                error( ...
                    'Pollbuster:ScenarioFormat', ...
                    'Format inconnu : scenario v2 ou ancien champ cfg attendu.');
            end

            if ~isfield(proposed, 'electorate')
                defaults = initialModel(D);
                proposed.electorate = defaults.electorate;
            end

            applyModel(proposed);

        catch err
            setStatus(['Chargement refuse : ' err.message], true);
        end
    end

    function exportCSV(varargin)
        if isempty(result)
            return
        end

        [name, folder] = uiputfile('*.csv', 'Exporter les resultats');

        if isequal(name, 0)
            return
        end

        try
            pb_export(result, resultData, fullfile(folder, name));
            setStatus('Scores, origines et composition sociale exportes.', false);

        catch err
            setStatus(err.message, true);
        end
    end

    function resetScenario(varargin)
        answer = questdlg( ...
            'Revenir au scenario initial et retirer les candidats ajoutes ?', ...
            'Reinitialiser', ...
            'Reinitialiser', 'Annuler', 'Annuler');

        if strcmp(answer, 'Reinitialiser')
            selectedRow = 1;
            selectedId = '';
            applyModel(initialModel(D));
        end
    end

    function testEngine(varargin)
        try
            pb_selftest();
            setStatus('Les tests de reference du moteur ont reussi.', false);

        catch err
            setStatus(['Echec des tests : ' err.message], true);
        end
    end

    function setStatus(message, isError)
        if isError
            color = [0.75 0.08 0.08];
        else
            color = [0.18 0.28 0.18];
        end

        set(H.status, ...
            'String', message, ...
            'ForegroundColor', color);
    end
end


%% Construction du scenario

function model = initialModel(D)
cfg = pb_defaults(D);

% Rendre explicites des options sinon lues par defaut dans le moteur.
cfg.options = setDefault(cfg.options, 'part', D.core.part);
cfg.options = setDefault(cfg.options, 'pb', struct());

kernelFields = fieldnames(D.core.params);

for index = 1:numel(kernelFields)
    key = kernelFields{index};

    cfg.options.pb = setDefault( ...
        cfg.options.pb, key, D.core.params.(key));
end

cfg.options = setDefault(cfg.options, 'homeSigma', 0.35);
cfg.options = setDefault(cfg.options, 'homeZoneSigma', 0.15);
cfg.options = setDefault(cfg.options, 'freeSigma', 0.25);
cfg.options = setDefault(cfg.options, 'ancrageVacant', 0.5);
cfg.options = setDefault(cfg.options, 'absFid', 0);
cfg.options = setDefault(cfg.options, 'lastVote', true);

% options.force est reconstruit depuis la colonne Force :
% ne pas afficher un reglage concurrent qui serait ecrase.
if isfield(cfg.options, 'force')
    cfg.options = rmfield(cfg.options, 'force');
end

model = struct();

model.cfg = cfg;
model.candidates = pb_candidates(D, cfg);

model.active = ismember( ...
    {model.candidates.id}', pb_cells(cfg.active));

model.themeZoneWeights = D.themes.PI;
% Valeurs de scenario illustratives, pas chiffres officiels.
% Le calage est desactive au demarrage pour conserver la reference.
model.electorate = struct( ...
    'enabled', false, ...          % Active le calage demographique.
    'registered', 50000000, ...    % Inscrits : nombre de personnes.
    'abstention', 0.20, ...        % Abstention parmi les inscrits.
    'blankInvalid', 0.02);         % Blancs/nuls parmi les votants.
end


function settings = editableSettings(model)
settings = struct( ...
    'electorate', model.electorate, ...
    'options', model.cfg.options, ...
    'build', model.cfg.build, ...
    'themesEnabled', model.cfg.themesEnabled, ...
    'salience', model.cfg.salience, ...
    'themeTheta', model.cfg.themeTheta, ...
    'themeProfiles', model.cfg.themeProfiles, ...
    'themeZoneWeights', model.themeZoneWeights);
end


function value = setDefault(value, key, fallback)
if ~isfield(value, key)
    value.(key) = fallback;
end
end


function id = uniqueCandidateId(model)
index = 1;
id = sprintf('candidat%d', index);

while any(strcmp({model.candidates.id}, id))
    index = index + 1;
    id = sprintf('candidat%d', index);
end
end


%% Validation

function validateModel(model, D)
candidates = model.candidates;
cfg = model.cfg;

assert(isstruct(candidates) && ~isempty(candidates), ...
    'Le catalogue des candidats est vide.');

assert(islogical(model.active) ...
    && numel(model.active) == numel(candidates), ...
    'Liste des activations incoherente.');

assert(any(model.active), ...
    'Activer au moins un candidat.');

ids = {candidates.id};

assert(numel(unique(ids)) == numel(ids), ...
    'Les identifiants des candidats doivent etre uniques.');

reservoirs = pb_build2027(D, cfg);
families = {reservoirs.id};

for index = 1:numel(candidates)
    candidate = candidates(index);

    assert(ischar(candidate.id) && isvarname(candidate.id) ...
        && ~strcmp(candidate.id, 'abst'), ...
        'Identifiant de candidat invalide ou reserve.');

    assert(ischar(candidate.name) && isrow(candidate.name) ...
        && ~isempty(strtrim(candidate.name)), ...
        'Le nom du candidat doit etre un texte non vide.');

    assert(any(strcmp({D.core.zones.id}, candidate.zone)) ...
        && isfield(D.colors, candidate.zone), ...
        'Zone inconnue ou sans couleur.');

    assert(any(strcmp(families, candidate.fam)), ...
        'La famille doit correspondre a un reservoir existant.');

    extraFamilies = pb_cells(candidate.fams);

    for familyIndex = 1:numel(extraFamilies)
        assert(any(strcmp(families, extraFamilies{familyIndex})), ...
            'Famille supplementaire inconnue.');
    end

    requireScalar(candidate.noto, 0, 1, 'Notoriete');
    requireScalar(candidate.force, 0, Inf, 'Force');
    requireScalar(candidate.led, 0, Inf, 'Led');

    assert(isscalar(candidate.meme) ...
        && (islogical(candidate.meme) || ...
        (isnumeric(candidate.meme) ...
        && ismember(candidate.meme, [0 1]))), ...
        'Sortant doit etre vrai ou faux.');

    validatePosition(candidate.by_hist, false);
    validatePosition(candidate.pos, true);
end

assert(islogical(cfg.themesEnabled) && isscalar(cfg.themesEnabled), ...
    'themesEnabled doit etre true ou false.');

requireScalar(cfg.themeTheta, 0, Inf, 'Theta');
requireScalar(cfg.build.P_RET, 0, 1, 'P_RET');

if isnumeric(cfg.build.LOYAL)
    requireScalar(cfg.build.LOYAL, 0, 1, 'LOYAL');
else
    assert(ischar(cfg.build.LOYAL) && isrow(cfg.build.LOYAL), ...
        'LOYAL doit etre un nombre ou le mode texte du constructeur.');
end

categories = {D.core.pcs.id};

for index = 1:numel(categories)
    requireScalar( ...
        cfg.options.part.(categories{index}), ...
        0, 1, ['Participation ' categories{index}]);
end

electorate = model.electorate;

assert(islogical(electorate.enabled) ...
    && isscalar(electorate.enabled), ...
    'electorate.enabled doit etre true ou false.');

requireScalar( ...
    electorate.registered, 1, Inf, 'Nombre d''inscrits');

assert(electorate.registered == fix(electorate.registered), ...
    'Le nombre d''inscrits doit etre entier.');

requireScalar( ...
    electorate.abstention, 0, 1, 'Abstention');

requireScalar( ...
    electorate.blankInvalid, 0, 1, 'Blancs et nuls');

if electorate.enabled
    assert(electorate.abstention < 1 ...
        && electorate.blankInvalid < 1, ...
        ['Cette interface exige des suffrages exprimes positifs ; ' ...
        'les scenarios sans aucun suffrage ne sont pas pris en charge.']);
end

checkFiniteValues(editableSettings(model));
end


function validatePosition(position, allowEmpty)
if allowEmpty && isempty(position)
    return
end

assert(isnumeric(position) && isreal(position) ...
    && isvector(position) && numel(position) == 2 ...
    && all(isfinite(position(:))), ...
    'Une position doit contenir deux coordonnees reelles finies.');
end


function requireScalar(value, minimum, maximum, label)
assert(isnumeric(value) && isreal(value) ...
    && isscalar(value) && isfinite(value) ...
    && value >= minimum && value <= maximum, ...
    '%s : nombre attendu entre %g et %g.', ...
    label, minimum, maximum);
end


function checkFiniteValues(value)
if isnumeric(value)
    assert(isreal(value) && all(isfinite(value(:))), ...
        'Un parametre contient une valeur non reelle ou non finie.');

elseif isstruct(value)
    keys = fieldnames(value);

    for element = 1:numel(value)
        for index = 1:numel(keys)
            checkFiniteValues(value(element).(keys{index}));
        end
    end

elseif iscell(value)
    for index = 1:numel(value)
        checkFiniteValues(value{index});
    end
end
end


function validateOutput(result)
assert(isfinite(result.E) && result.E > 0, ...
    'Aucun suffrage valide.');

assert(all(isfinite(result.V(:))) ...
    && all(result.V(:) >= -1e-8), ...
    'Le moteur produit des voix invalides.');

assert(all(isfinite(result.pct(:))) ...
    && all(result.pct(:) >= -1e-8) ...
    && abs(sum(result.pct) - 100) < 1e-6, ...
    'Les scores sont invalides.');

assert(all(isfinite(result.lost(:))) ...
    && all(result.lost(:) >= -1e-8), ...
    'Les pertes vers l''abstention sont invalides.');

tolerance = max(1e-3, result.totalReservoir * 1e-10);

assert(abs(result.conservationError) < tolerance, ...
    'La conservation des voix a echoue.');
end


%% Table generique de parametres

function [paths, values] = flattenSettings(value, prefix)
paths = {};
values = {};

if isstruct(value) && isscalar(value) ...
        && ~isempty(fieldnames(value))

    keys = fieldnames(value);

    for index = 1:numel(keys)
        key = keys{index};

        [childPaths, childValues] = flattenSettings( ...
            value.(key), [prefix {key}]);

        paths = [paths; childPaths]; %#ok<AGROW>
        values = [values; childValues]; %#ok<AGROW>
    end

else
    paths = {prefix};
    values = {encodeValue(value)};
end
end


function text = encodeValue(value)
if ischar(value) && (isrow(value) || isempty(value))
    text = value;
else
    text = jsonencode(value);
end
end


function value = decodeValue(text, previous)
text = char(string(text));

if ischar(previous)
    value = text;
    return
end

value = jsondecode(text);

if isnumeric(previous)
    assert(isnumeric(value), 'Une valeur numerique est attendue.');

    % jsondecode renvoie souvent les vecteurs en colonnes.
    if isvector(previous) && numel(value) == numel(previous)
        value = reshape(value, size(previous));
    end

    assert(isequal(size(value), size(previous)), ...
        'Conserver les dimensions du parametre.');

elseif islogical(previous)
    assert(islogical(value) ...
        && isequal(size(value), size(previous)), ...
        'Utiliser true ou false, avec les dimensions initiales.');

elseif isstruct(previous)
    assert(isstruct(value), 'Un objet JSON est attendu.');

elseif iscell(previous)
    assert(iscell(value) || isstruct(value) || isempty(value), ...
        'Un tableau JSON est attendu.');
end
end


function value = getNested(value, path)
for index = 1:numel(path)
    value = value.(path{index});
end
end


function value = setNested(value, path, replacement)
key = path{1};

if isscalar(path)
    value.(key) = replacement;
else
    value.(key) = setNested( ...
        value.(key), path(2:end), replacement);
end
end


%% Utilitaires graphiques et numeriques

function handle = button(parent, label, position, callback)
handle = uicontrol( ...
    parent, ...
    'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', position, ...
    'String', label, ...
    'Callback', callback);
end


function total = structTotal(value)
total = 0;
keys = fieldnames(value);

for index = 1:numel(keys)
    total = total + value.(keys{index});
end
end

function releaseCalculationLock(figureHandle)
%RELEASECALCULATIONLOCK Libere le verrou sans variable partagee.

if ~isgraphics(figureHandle)
    return
end

setappdata(figureHandle, 'PollbusterBusy', false);
set(figureHandle, 'Pointer', 'arrow');
end

function description = parameterDescription(path)
%PARAMETERDESCRIPTION Documentation des parametres exposes dans la table.

descriptions = {
    'electorate.enabled', ...
    ['Active le calage du volume final de suffrages sur les inscrits ' ...
    'et le taux d''abstention choisis.'];

    'electorate.registered', ...
    'Nombre total d''inscrits, en personnes et non en millions.';

    'electorate.abstention', ...
    'Part des inscrits qui ne votent pas : 0.30 signifie 30 %.';

    'electorate.blankInvalid', ...
    ['Part des votants qui deposent un bulletin blanc ou nul : ' ...
    '0.02 signifie 2 % des votants.'];

    'options.beta', ...
    ['Exposant d''attraction utilise pour les segments fideles ' ...
    'lorsque leur famille est representee.'];

    'options.betaVac', ...
    ['Exposant d''attraction des segments dont la famille est vacante ; ' ...
    'sert aussi de repli pour les flottants.'];

    'options.betaFlot', ...
    'Exposant d''attraction propre aux flottants, lorsqu''il est defini.';

    'options.home', ...
    'Regle l''avantage accorde aux candidats de la famille du reservoir.';

    'options.lambda', ...
    'Regle l''intensite de l''effet des porosites entre zones politiques.';

    'options.kappa', ...
    ['Intensite de l''usure : les probabilites sont multipliees ' ...
    'par 1 - kappa * cont du candidat.'];

    'options.absFlot', ...
    ['Regle l''attraction de l''abstention pour les flottants et ' ...
    'certains electeurs liberes ; ce n''est pas un taux national.'];

    'options.absFid', ...
    ['Regle l''attraction de l''abstention pour les segments fideles ; ' ...
    'ce n''est pas un taux national.'];

    'options.homeSigma', ...
    ['Tolerance au deplacement politique avant liberation du socle : ' ...
    'une valeur plus grande rend les deplacements moins penalisants.'];

    'options.homeZoneSigma', ...
    ['Largeur de la proximite a une zone utilisee pour l''avantage ' ...
    'familial hors correspondance exacte de zone.'];

    'options.freeSigma', ...
    'Largeur du mecanisme de proximite pour les electeurs liberes.';

    'options.ancrageVacant', ...
    'Ancrage utilise lorsque le reservoir familial n''a aucun fidele.';

    'options.lastVote', ...
    'Conserve ou ignore la zone du dernier vote des electeurs flottants.';

    'options.groupes', ...
    ['Mode de regroupement des candidats pour le partage des socles : ' ...
    'heritiers, fam ou aucun.'];

    'options.traj.force', ...
    'Poids de l''ancrage des profils sociaux sur les profils historiques.';

    'options.traj.forceMeme', ...
    ['Poids historique utilise lorsqu''un ancien candidat ' ...
    'represente sa famille.'];

    'options.traj.delta', ...
    ['Extrapolation des penetrations sociales a partir des deux ' ...
    'derniers points historiques.'];

    'options.pb.ALPHA', ...
    ['Exposant applique aux attractions avant normalisation ; ' ...
    'au-dessus de 1, accentue les ecarts d''attraction.'];

    'options.pb.GAMMA', ...
    ['Melange entre profil social de la zone d''origine et profil ' ...
    'recompose par proximite aux autres zones.'];

    'options.pb.SIGMA_BOOST', ...
    'Multiplicateur des matrices de dispersion de l''attraction spatiale.';

    'options.pb.SIGMA_ORPHAN', ...
    'Distance caracteristique de detection des espaces politiques vacants.';

    'options.pb.ORPHAN_MAX', ...
    'Amplitude maximale du bonus de proximite des espaces vacants.';

    'options.pb.SIGMA_RIVAL', ...
    'Distance sur laquelle les candidats proches influencent la rivalite.';

    'options.pb.SIGMA_BLEND', ...
    'Largeur du melange des profils des differentes zones politiques.';

    'options.pb.AFF_SIGMA', ...
    'Largeur de l''affinite entre categories sociales et zones politiques.';

    'options.pb.SIGMA_ID_MIN', ...
    'Tolerance identitaire minimale aux deplacements politiques.';

    'options.pb.SIGMA_ID_MAX', ...
    ['Tolerance identitaire superieure, modulee par la notoriete ' ...
    'et l''ancrage du candidat.'];

    'options.pb.ID_FLOOR', ...
    'Plancher du coefficient de maintien de l''identite politique.';

    'options.pb.IDF_WALL', ...
    'Multiplicateur identitaire lors du franchissement d''une barriere.';

    'options.pb.IDF_SIGN_X', ...
    'Distance horizontale declenchant le regime de changement de signe.';

    'options.pb.IDF_SIGN', ...
    'Multiplicateur identitaire pour certains changements de signe de X.';

    'options.pb.IDF_FAR_X', ...
    'Distance horizontale declenchant le regime de deplacement lointain.';

    'options.pb.IDF_FAR', ...
    'Multiplicateur identitaire pour certains deplacements lointains.';

    'options.pb.ABST_NOTO', ...
    'Force de base attribuee a l''option abstention dans le noyau.';

    'options.pb.NOTO_FLOOR', ...
    'Plancher de la force issue de la notoriete et de l''ancrage.';

    'options.pb.BONUS_BASE', ...
    'Composante fixe de la force relative du candidat.';

    'options.pb.BONUS_RANGE', ...
    'Amplitude du bonus lie a la notoriete relative aux rivaux proches.';

    'options.pb.POS_FLOOR', ...
    'Composante minimale de l''attraction liee a la position politique.';

    'options.pb.POS_RANGE', ...
    'Amplitude de la composante spatiale normalisee de l''attraction.';

    'options.pb.POROSITY_AMP', ...
    'Amplitude de modulation de l''attraction par les porosites sociales.';

    'options.pb.REL_FORCE', ...
    'Active une normalisation relative des profils sociaux des zones.';

    'options.pb.REL_FORCE_ZONES', ...
    'Zones auxquelles appliquer la normalisation relative des profils.';

    'options.pb.ZP_PCS_NEG', ...
    'Penalite de changement de zone pour profils sociaux anticorreles.';

    'options.pb.ZP_PCS_LOW', ...
    'Penalite de changement de zone pour profils sociaux peu correles.';

    'options.pb.ZP_X_SIGN', ...
    'Seuil horizontal pour la penalite de changement de signe de X.';

    'options.pb.ZP_X_SIGN_MAX', ...
    'Plafond de la penalite horizontale de changement de signe.';

    'options.pb.ZP_X_SIGN_K', ...
    'Pente de la penalite horizontale de changement de signe.';

    'options.pb.ZP_X_FAR', ...
    'Seuil de distance horizontale pour la penalite d''eloignement.';

    'options.pb.ZP_X_FAR_K', ...
    'Pente de la penalite horizontale d''eloignement.';

    'options.pb.ZP_WALL', ...
    'Penalite de franchissement d''une barriere entre zones politiques.';

    'build.P_RET', ...
    ['Parametre de reconstruction du retour presidentiel ; ' ...
    'agit sur la masse des reservoirs, pas directement sur ' ...
    'l''abstention nationale.'];

    'build.LOYAL', ...
    ['Loyaute des electeurs revenants envers leur famille d''origine ; ' ...
    'un mode texte active le traitement specifique du constructeur.'];

    'build.SOCLE24', ...
    'Regroupe certains flux de 2024 dans les socles familiaux.';

    'themesEnabled', ...
    'Active ou desactive l''application des coefficients thematiques.';

    'themeTheta', ...
    ['Exposant des avantages thematiques relatifs ; ' ...
    '0 neutralise leur effet lorsque les profils sont strictement positifs.'];
    };

index = find(strcmp(descriptions(:,1), path), 1);

if ~isempty(index)
    description = descriptions{index,2};
    return
end

if startsWith(path, 'options.part.')
    description = [ ...
        'Poids de participation de cette categorie sociale dans ' ...
        'la repartition interne des reservoirs ; ne fixe pas ' ...
        'a lui seul le taux national d''abstention.'];

elseif startsWith(path, 'options.cont.')
    description = [ ...
        'Coefficient de continuite/usure du candidat, ' ...
        'utilise avec options.kappa.'];

elseif startsWith(path, 'options.prof.')
    description = [ ...
        'Penetration sociale de reference de la famille pour ' ...
        'la ventilation des reservoirs entre categories.'];

elseif startsWith(path, 'options.traj.profils.')
    description = [ ...
        'Serie historique de profils sociaux utilisee pour ' ...
        'l''ancrage et l''extrapolation des trajectoires.'];

elseif startsWith(path, 'salience.')
    description = [ ...
        'Poids relatif du theme dans la campagne ; ' ...
        'ce n''est pas un pourcentage d''intentions de vote.'];

elseif startsWith(path, 'themeProfiles.')
    description = [ ...
        'Coefficient du candidat sur ce theme ; ' ...
        'hypothese du modele et non statistique observee.'];

elseif startsWith(path, 'themeZoneWeights.')
    description = 'Importance relative du theme dans cette zone politique.';

else
    description = [ ...
        'Parametre non documente dans cette version : ' ...
        'verifier son utilisation dans le moteur avant modification.'];
end
end

function result = calibrateElectorate(result, electorate)
%CALIBRATEELECTORATE Ajuste l'echelle des volumes, pas les scores.
%
% Les pertes internes du moteur restent distinctes de l'abstention
% nationale. Tous les volumes internes sont multiplies par le meme
% facteur pour conserver leurs relations additives.

if ~electorate.enabled
    return
end

registered = electorate.registered;

voters = registered * (1 - electorate.abstention);

blankInvalidVotes = voters * electorate.blankInvalid;

targetExpressed = voters - blankInvalidVotes;

assert(isfinite(result.E) && result.E > 0, ...
    'Le resultat initial ne contient aucun suffrage exprime.');

factor = targetExpressed / result.E;

assert(isfinite(factor) && factor > 0, ...
    'Facteur de calage invalide.');

% Conserver les volumes avant calage pour diagnostic.
result.calibration = struct( ...
    'enabled', true, ...
    'factor', factor, ...
    'originalExpressed', result.E, ...
    'originalReservoirMass', result.totalReservoir);

% Grandeurs additives exprimees en personnes.
result.V = result.V * factor;
result.T = sum(result.V, 2);
result.E = sum(result.T);

result.sources = result.sources * factor;
result.lost = result.lost * factor;

% Les masses des reservoirs sont exprimees en millions.
for index = 1:numel(result.reservoirs)
    reservoir = result.reservoirs{index};

    reservoir.fid = reservoir.fid * factor;

    if isfield(reservoir, 'fidP')
        reservoir.fidP = reservoir.fidP * factor;
    end

    for field = {'flot', 'orig'}
        key = field{1};

        if ~isfield(reservoir, key)
            continue
        end

        entries = fieldnames(reservoir.(key));

        for entryIndex = 1:numel(entries)
            entry = entries{entryIndex};

            reservoir.(key).(entry) = ...
                reservoir.(key).(entry) * factor;
        end
    end

    result.reservoirs{index} = reservoir;
end

result.totalReservoir = result.totalReservoir * factor;

result.conservationError = ...
    result.E + sum(result.lost) - result.totalReservoir;

result.pct = 100 * result.T / result.E;

% Le calage uniforme ne modifie ni les barycentres ni les
% probabilites d'attraction du moteur.

result.electorate = struct( ...
    'registered', registered, ...
    'abstentionRate', electorate.abstention, ...
    'abstainers', registered - voters, ...
    'voters', voters, ...
    'blankInvalidRate', electorate.blankInvalid, ...
    'blankInvalidVotes', blankInvalidVotes, ...
    'expressed', result.E);

% IMPORTANT :
% result.lost reste une perte interne au modele.
% result.electorate.abstainers est l'abstention nationale choisie.
% Ces deux nombres ne doivent pas etre additionnes.
end

function text = formatVotes(value)
%FORMATVOTES Affiche les voix sans decimales, avec espaces de milliers.
% Exemple : 9661600 -> '9 661 600'

text = sprintf('%.0f', value);

text = regexprep( ...
    text, ...
    '(\d)(?=(\d{3})+$)', ...
    '$1 ');
end