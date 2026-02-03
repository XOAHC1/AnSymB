%% Define base values
addpath(".\analysis\")
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

    condition_sole_data = struct();

    data_path = "subject_data\sole-data\" + subject + "\" + condition +".txt";
    
    try
        data = readtable(data_path);
    catch ME 
        % Placeholder for missing data
        data = table(); % empty table
    end 

    condition_sole_data.data = data;
    condition_sole_data.steps = get_steps(data);
    condition_sole_data.trials = get_trials(condition_sole_data);

end

% Read in sole data from all trials by one subject
function subject_sole_data = read_subject_sole_data(subject)

    % nice structure:
    %  20       6       10
    % subject.condition.trial
    %                  .steps
    %                  . 

    CONDITIONS = ["br", "bvr", "vw", "w", "h", "vh"];
    subject_sole_data = struct();

    for c = 1:numel(CONDITIONS)
        cond = CONDITIONS(c);
        subject_sole_data.(cond) = read_condition_sole_data(subject, cond);
    end
end

% external use
function plot_sole_data(condition_data, mark_steps, plotLabel)
    %PLOT_SOLE_DATA Plot sole pressure data from a table
    %
    %   plot_sole_data(data)
    %   plot_sole_data(data, "S01 - br")

    % ---- Input checks ----
    if nargin < 1 || isempty(condition_data)
        error("Input data must be a non-empty table.");
    end

    if nargin < 2 || isempty(mark_steps)
        mark_steps = false;
    end

    if nargin < 3 || isempty(plotLabel)
        plotLabel = "some Data";
    end

    % get sole data
    data = condition_data.data;

    % ---- Column indices  ----
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

    if mark_steps
        % get steps
        steps = condition_data.steps;

        % get step peak times
        steps_r = steps.right;
        n_steps_r = numel(steps_r);
        step_times_r = arrayfun(@(i) steps_r(i).peakTime, 1:n_steps_r);
        step_types_r = arrayfun(@(i) steps_r(i).step_type, 1:n_steps_r);
        
        stamp_indices_r   = step_types_r == "stamp";
        stamps_r          = step_times_r(stamp_indices_r);

        walking_indices_r = step_types_r == "walking";
        walking_r         = step_times_r(walking_indices_r);

        turning_indices_r = step_types_r == "turning";
        turning_r         = step_times_r(turning_indices_r);



        % and for the left
        steps_l = steps.left;
        n_steps_l = numel(steps_l);
        step_times_l = arrayfun(@(i) steps_l(i).peakTime, 1:n_steps_l);
        step_types_l = arrayfun(@(i) steps_l(i).step_type, 1:n_steps_l);

        stamp_indices_l   = step_types_l == "stamp";
        stamps_l          = step_times_l(stamp_indices_l);

        walking_indices_l = step_types_l == "walking";
        walking_l         = step_times_l(walking_indices_l);

        turning_indices_l = step_types_l == "turning";
        turning_l         = step_times_l(turning_indices_l);


    end

    % Right foot
    nexttile
    plot(tR, [R_heel R_mid R_front R_total], 'LineWidth', 1.2)
    hold on
    if mark_steps 
        if ~isempty(walking_r) 
            plot(walking_r, 500, "Color", "red", "Marker", "+");
        end
        if ~isempty(stamps_r) 
            plot(stamps_r, 550, "Color", "magenta", "Marker", "diamond");
        end
        if ~isempty(turning_r) 
            plot(turning_r, 450, "Color", "green", "Marker", "*");
        end
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
        if ~isempty(walking_l)
            plot(walking_l, 500, "Color", "red", "Marker", "+");
        end
        if ~isempty(stamps_l)
            plot(stamps_l, 550, "Color", "magenta", "Marker", "diamond");
        end
        if ~isempty(turning_l)
            plot(turning_l, 450, "Color", "green", "Marker", "*");
        end
    end
    hold off
    grid on
    title("Left Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

end

function steps_side = get_steps_one_side(t, heel, mid, front, total)

    % find individual steps
    steps_side = struct([]);

    cf = 0.05;
    th_c = cf * max(total);

    in_contact = total > th_c;

    edges = diff([false; in_contact; false]);

    % first and Last in contact indices
    onsets  = find(edges == 1);
    offsets = find(edges == -1) - 1; 

    % extract steps from data
    nEvents = numel(onsets);

    % prep for rolling
    x_h = 0;
    x_m = 0.5;
    x_f = 1;

    for i = 1:nEvents
        % seperate individual steps
        idx = onsets(i):offsets(i);
        t_evt = t(idx);

        tot = total(idx);
        h = heel(idx);
        m = mid(idx);
        f = front(idx);

        % Peak times
        [max_h ,mih] = max(h);
        [max_m ,mim] = max(m);
        [max_f ,mif] = max(f);
        [peakForce, peakIndex] = max(tot);

        % partial force relative to total at maximum
        steps_side(i).heelPropAtMax = max_h / tot(mih);
        steps_side(i).frontPropAtMax = max_f / tot(mif);

        % Rise slope
        dt = mean(diff(t_evt));
        steps_side(i).maxSlope = max(diff(tot)) / dt;

        % Contact duration
        steps_side(i).duration = t_evt(end) - t_evt(1);

        % peak time
        steps_side(i).peakTime = t_evt(peakIndex);
        steps_side(i).peakForce = peakForce;

        % rolling
        % COP computation
        cop = (h * x_h + m * x_m + f * x_f) ./ tot;

        % COP forward velocity
        dt = mean(diff(t));
        cop_vel = diff(cop) / dt;

        % Rolling metric: COP smoothness
        steps_side(i).rolling = (mean(cop_vel));
        
        % get step type
        steps_side(i).step_type = step_type(steps_side(i));

    end

end

function steps = get_steps(condition_data)
    
    % extract Data
    time  = condition_data{:, 1};
    % right side
    front_r = condition_data{:, 2};
    mid_r = condition_data{:, 3};
    heel_r = condition_data{:, 4};
    total_r = condition_data{:, 5};
    % left side
    front_l = condition_data{:, 9};
    mid_l = condition_data{:, 8};
    heel_l = condition_data{:, 7};
    total_l = condition_data{:, 10}; 
    
    % initialise structure
    steps = struct();

    steps.right = get_steps_one_side(time, heel_r, mid_r, front_r, total_r);
    steps.left = get_steps_one_side(time, heel_l, mid_l, front_l, total_l);
     
end

function step_type = step_type(step)

    % stamp thresholds
    ROLLING_TH = 0.2 * 1;       % seconds
    DURATION_TH = 2 * 1;        % seconds
    SLOPE_TH   = 3000 / .7;      % pressure / s
    MAX_H_TH   = 0.5  * 100;    % Proportion

    % walking threshlods
    ROLLING_WALK_TH = 0.9;
    DURATION_WALK_TH = 1;
    SLOPE_WALK_TH = [0, 10000];


    if ...
        step.heelPropAtMax < MAX_H_TH && ...
        -0.1 < step.rolling && step.rolling < ROLLING_TH && ...
        step.duration < DURATION_TH && ...
        step.maxSlope > SLOPE_TH

        step_type = "stamp";

    elseif ...
        step.rolling > ROLLING_WALK_TH && ...
        step.duration < DURATION_WALK_TH && ...
        step.maxSlope > SLOPE_WALK_TH(1) && ...
        step.maxSlope < SLOPE_WALK_TH(2)

        step_type = "walking";

    else 
        step_type = "turning";
    end

    
    
end

function trials = get_trials(condition_data)

    % Input: 
    %   trial_data:
    %       struct with:
    %           .data   (table of data, from stamp to turning steps)
    %           .steps  (metadata around data)
    %       Limited to time from stamp to turning steps

    trials = struct();

    % cd = condition_data.steps

    % identify trial borders
    % stamps to start trials
    stamps_idx = strcmp([condition_data.steps.right.step_type], "stamp");
    n_stamps = sum(stamps_idx);
    stamps = condition_data.steps.right(stamps_idx);
    trial_starts = arrayfun(@(s) stamps(s).peakTime, 1:n_stamps)*100;

    % turning steps, to end trials
    turning_steps_idx = strcmp([condition_data.steps.right.step_type], "turning");
    n_turning = sum(turning_steps_idx);
    turning_steps = condition_data.steps.right(turning_steps_idx);
    turning_step_times = arrayfun(@(s) turning_steps(s).peakTime, 1:n_turning)*100;

    % match up stamps and turning steps
    last_trial_end_idx = 1;
    trial_ends = zeros(n_stamps, 1);
    for s = 1:n_stamps
        t = trial_starts(s);
        while turning_step_times(last_trial_end_idx) < t
            last_trial_end_idx = last_trial_end_idx + 1;
        end
        trial_ends(s) = turning_step_times(last_trial_end_idx);
    end

    % make indices to integers
    trial_starts = round(trial_starts);
    trial_ends = round(trial_ends);

    % call analysis for individual trials
    for i = 1:n_stamps
        trial_data = condition_data.data(trial_starts(i):trial_ends(i), :);
        trial = analyse_trial(trial_data);
        trials(i).n_stride_r = trial.n_stride_r;
        trials(i).n_stride_l = trial.n_stride_l;
        trials(i).stride_freq_r = trial.stride_freq_r;
        trials(i).stride_freq_l = trial.stride_freq_l;
        trials(i).stride_freq = trial.stride_freq;
        trials(i).duration = trial.duration;
        trials(i).start = trial.start;
    end

end

function trial = analyse_trial(trial_data)

    trial = struct();
    % trial_data = cond_data_data{start:stop, :};

    % get relative time
    trial_time_abs = trial_data{:, 1};
    trial_start_time = trial_time_abs(1);
    trial_time = trial_time_abs - trial_start_time;
    trial_duration = trial_time(end);

    trial_steps = get_steps(trial_data);

    % stride frequency
    n_stride_r = numel(trial_steps.right);
    n_stride_l = numel(trial_steps.left);

    stride_freq_r = 60 / mean(diff([trial_steps.right.peakTime]));
    stride_freq_l = 60 / mean(diff([trial_steps.left.peakTime]));
    stride_freq_mean = mean([stride_freq_r * n_stride_r, stride_freq_l * n_stride_l])/ (n_stride_r + n_stride_l);



    trial(1).n_stride_r = n_stride_r;
    trial.n_stride_l = n_stride_l;
    trial.stride_freq_r = stride_freq_r;
    trial.stride_freq_l = stride_freq_l;
    trial.stride_freq = stride_freq_mean;
    trial.duration = trial_duration;
    trial.start = trial_start_time;


end
% rechter Peak bis rechter peak -> stride

    % 

%% Testing

s_data = read_subject_sole_data(3);
c_data = s_data.h;

plot_sole_data(c_data, true);


c_data.trials(1)