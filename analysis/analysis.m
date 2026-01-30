%% Define base values
clearvars

% Data structure
SOLE_DATA_PATH = "subject_data\sole-data";
VR_DATA_PATH = "subject_data\vr_data";

% Experiment related
N_SUBJECTS = 21;
CONDITIONS = ["br", "bvr", "vw", "w", "h", "vh"];

%% Define Functions

% Read in sole data for one condition by one subject
function condition_sole_data = read_condition_sole_data(subject, condition)

    % Data Format:
    %     1   , 2     , 3     , 4     , 5     , 6     , 7     , 8     , 9     , 10    , 11
        % Time, R-front, R-mid, R-heel, R-total, Time, L-heel, L-mid, L-front, L-total, Time
    % 
    % Data is also accessable by collumn headers. Thoose change depending on the soles used, therefore access via index is to be preferred.
    data_path = "subject_data\sole-data\" + subject + "\" + condition +".txt";
    
    try
        condition_sole_data = readtable(data_path);
    catch ME
        % Warn but do not stop execution
        % warning("Missing or unreadable file for subject %s, condition %s.\n%s", ...
        % subject, cond, ME.message);
        
        % Placeholder for missing data
        condition_sole_data = table(); % empty table
    end 
end

% Read in sole data from all trials by one subject
function subject_sole_data = read_subject_sole_data(subject)

    CONDITIONS = ["br", "bvr", "vw", "w", "h", "vh"];
    subject_sole_data = struct();

    for c = 1:numel(CONDITIONS)
        cond = CONDITIONS(c);
        subject_sole_data.(cond) = read_condition_sole_data(subject, cond);
    end
end

function plot_sole_data(data, plotLabel)
    %PLOT_SOLE_DATA Plot sole pressure data from a table
    %
    %   plot_sole_data(data)
    %   plot_sole_data(data, "S01 - br")

    % ---- Input checks ----
    if nargin < 1 || isempty(data)
        error("Input data must be a non-empty table.");
    end

    if nargin < 2
        plotLabel = "";
    end

    % ---- Column indices (based on your format) ----
    tR = data{:,1};     % Right foot time
    R_front = data{:,2};
    R_mid   = data{:,3};
    R_heel  = data{:,4};
    R_total = data{:,5};

    tL = data{:,6};     % Left foot time
    L_heel  = data{:,7};
    L_mid   = data{:,8};
    L_front = data{:,9};
    L_total = data{:,10};

    % ---- Plot ----
    figure('Name', plotLabel, 'Color', 'w');

    tiledlayout(2,1,"TileSpacing","compact")

    mark_steps = true;
    steps = get_steps(data);
    if mark_steps
        steps_r = steps.right;
        n_steps_r = numel(steps_r);
        step_times_r = arrayfun(@(i) steps_r(i).peakTime, 1:n_steps_r);
        % and for the left
        steps_l = steps.left;
        n_steps_l = numel(steps_l);
        step_times_l = arrayfun(@(i) steps_l(i).peakTime, 1:n_steps_l);


    end

    % Right foot
    nexttile
    plot(tR, [R_heel R_mid R_front R_total], 'LineWidth', 1.2)
    hold on
    if mark_steps 
        plot(step_times_r, 500, "Color", "red", "Marker", "+");
    end
    hold off
    grid on
    title("Right Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

    % Left foot
    nexttile
    plot(tL, [L_heel L_mid L_front L_total], 'LineWidth', 1.2)
    hold on
    if mark_steps 
        plot(step_times_l, 500, "Color", "red", "Marker", "+");
    end
    hold off
    grid on
    title("Left Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

end

% get individual trials
function trials = seperate_trials(condition_sole_data)
    % return sturct of individual trials

    % Notes to stump signal:
    % no rolling pattern
    % slower than step
    % more force in mid-foot than usual
    
    trials = struct();


end

function steps = get_steps(condition_data)
    mark_steps = true;

    % Fields in Output:
        % rolling
        % max slope
        % duration
        % peakTime
    steps = struct();

    steps.right = struct([]);
    steps.left = struct([]);
    
    % extract relevant data from data
    t = condition_data{:, 1};
    right = condition_data{:, 5};
    left = condition_data{:, 10};

    % determin contact phases
    cf = 0.05; % contact factor
    th_r = cf * max(right);
    th_l = cf * max(left);
    
    r_in_contact = right > th_r;
    l_in_contact = left > th_l;

    % find connected components in sole data (aka steps)
    r_edges = diff([false; r_in_contact;false]);
    l_edges = diff([false; l_in_contact; false]);

    % first and Last in contact indices
    r_onsets  = find(r_edges == 1);
    r_offsets = find(r_edges == -1) - 1; 

    l_onsets = find(l_edges == 1);
    l_offsets = find(l_edges == -1) - 1;

    % extract steps from data
    nEvents_r = numel(r_onsets);
    nEvents_l = numel(l_onsets);

  
    for i = 1:nEvents_r
        idx = r_onsets(i):r_offsets(i);

        t_evt = t(idx);
        heel  = condition_data{idx,4};
        mid   = condition_data{idx,3};
        front = condition_data{idx,2};
        tot   = condition_data{idx, 5};

        % Peak times
        [max_h ,mih] = max(heel);
        [max_m ,mim] = max(mid);
        [max_f ,mif] = max(front);

        % rolling
        steps.right(i).rolling = ...
            max(abs( ...
                [t_evt(mih), t_evt(mih), t_evt(mim)] - ...
                [t_evt(mim), t_evt(mif), t_evt(mif)] ...
            ));

        % partial force relative to total at maximum
        steps.right(i).heelPropAtMax = max_h / tot(mih);
        steps.right(i).frontPropAtMax = max_f / tot(mif);

        % Rise slope
        dt = mean(diff(t_evt));
        steps.right(i).maxSlope = max(diff(tot)) / dt;

        % Contact duration
        steps.right(i).duration = t_evt(end) - t_evt(1);

        % peak time
        [~, peakIndex] = max(tot);
        steps.right(i).peakTime = t_evt(peakIndex);
    end

    % same for the left side
    for i = 1:nEvents_l
        idx = l_onsets(i):l_offsets(i);

        t_evt = t(idx);
        heel  = condition_data{idx,7};
        mid   = condition_data{idx,8};
        front = condition_data{idx,9};
        tot   = condition_data{idx, 10};

        % Peak times
        [max_h ,mih] = max(heel);
        [max_m ,mim] = max(mid);
        [max_f ,mif] = max(front);

        % rolling
        steps.left(i).rolling = ...
            max(abs( ...
                [t_evt(mih), t_evt(mih), t_evt(mim)] - ...
                [t_evt(mim), t_evt(mif), t_evt(mif)] ...
            ));

        % partial force relative to total at maximum
        steps.left(i).heelPropAtMax = max_h / tot(mih);
        steps.left(i).frontPropAtMax = max_f / tot(mif);

        % Rise slope
        dt = mean(diff(t_evt));
        steps.left(i).maxSlope = max(diff(tot)) / dt;

        % Contact duration
        steps.left(i).duration = t_evt(end) - t_evt(1);

        % peak time
        [~, peakIndex] = max(tot);
        steps.left(i).peakTime = t_evt(peakIndex);
    end
end


% identify stamps in struct of steps
function get_stamps(steps_total, condition_data)

    steps = steps_total.right;
    t = condition_data.Var1;
    total = condition_data{:, 5};

    nSteps = numel(steps);
    
    ROLLING_TH = 0.08 * 5;   % seconds
    SLOPE_TH   = 3000 / 6;   % pressure / s
    DUR_TH     = 0.25 * 20;   % seconds
    MAX_H_TH   = 0.5  * 1;  
    % MAX_F_TH   = 

    mark_stamps = true;
    for i = 1:nSteps
        steps(i).isStamp = ...
            steps(i).heelPropAtMax < MAX_H_TH;% && ...
            % steps(i).maxSlope > SLOPE_TH && ...
            % steps(i).duration < DUR_TH;
    end
    nStamp = 0;
    if mark_stamps
        figure; plot(t, total); hold on
        for i = 1:nSteps
            if steps(i).isStamp
                % s = i
                nStamp = nStamp + 1
                x = steps(i).heelPropAtMax
                plot(steps(i).peakTime, 500, "Color", "red", "Marker", "diamond");
            end
        end
        legend()
    end

end

%% Testing

data = read_condition_sole_data(3, "h");
steps = get_steps(data);
plot_sole_data(data);

get_stamps(steps, data);