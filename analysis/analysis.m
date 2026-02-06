%% Define Functions
clearvars

%% Read in Data

% Read in sole data for one condition by one subject
function condition_sole_data = read_condition_sole_data(subject, condition, manual_trials)

    % Data Format:
    %     1   , 2     , 3     , 4     , 5     , 6     , 7     , 8     , 9     , 10    , 11
        % Time, R-front, R-mid, R-heel, R-total, Time, L-heel, L-mid, L-front, L-total, Time
    % 
    % Data is also accessable by collumn headers. Thoose change depending on the soles used, therefore access via index is to be preferred.

    if nargin < 3
        manual_trials = false;
    end

    if manual_trials
        manual_trial_params = [string(subject), condition];
    else
        manual_trial_params = [];
    end

    condition_sole_data = struct();

    filename = "subject_data\sole-data\" + subject + "\" + condition +".txt";
    
    try
        data = readtable(filename, "VariableNamingRule", "preserve");

        var_names = data.Properties.VariableNames;

        % rename vars
        heels = contains(var_names, "heel");
        mids = contains(var_names, "mid");
        fronts = contains(var_names, "front");

        data = renamevars(data, heels, ["R_heel", "L_heel"]);
        data = renamevars(data, mids, ["R_mid", "L_mid"]);
        data = renamevars(data, fronts, ["R_front", "L_front"]);

        data = renamevars(data, [1, 5, 6, 10, 11], ["time_r", "R_total", "time", "L_total", "time_l"]);

        % get time of experiment
        fid = fopen(filename, "r");
        str = fgetl(fid);
        fclose(fid);

        token = regexp(str, '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d{3}', 'match');
        dt = datetime(token{1}, 'InputFormat', 'yyyy-MM-dd_HH-mm-ss-SSS');


    catch ME 
        % Placeholder for missing data
        fprintf('no Data for condition: ' + condition);
        return
    end 

    condition_sole_data.data = data;
    condition_sole_data.steps = get_steps(data);
    [condition_sole_data.trials, msf, std_freq] = get_trials(condition_sole_data, manual_trial_params);
    condition_sole_data.experiment_time = dt;
    condition_sole_data.mean_step_freq = msf;
    condition_sole_data.std_step_freq = std_freq;

    fprintf("Imported " + condition + " data for Subject " + subject + ". \n")

end

% Read in sole data from all trials by one subject. 
function subject_sole_data = read_subject_sole_data(subject, manual_trials, bonus_conditions)

    % nice structure:
    %  20       6       10
    % subject.condition.trial
    %                  .steps
    %                  . 

    if nargin < 2 || isempty(manual_trials)
        manual_trials = false;
    end

    if nargin < 3 || isempty(bonus_conditions)
        bonus_conditions = [];
    end

    CONDITIONS = cat(2, ["br", "bvr", "vw", "w", "h", "vh"], bonus_conditions);
    n_conditions = numel(CONDITIONS);
    subject_sole_data = struct();

    experiment_times = NaT(n_conditions);

    for c = 1:n_conditions
        cond = CONDITIONS(c);
        subject_sole_data.(cond) = read_condition_sole_data(subject, cond, manual_trials);
        experiment_times(c) = subject_sole_data.(cond).experiment_time;
    end

    [~, idx] = sort(experiment_times);
    sequence = CONDITIONS(idx);

    for s = 1:n_conditions
        subject_sole_data.(sequence(s)).place_in_sequence = s;
    end

    % log
    fprintf("Imported Data of Subject " + subject + "\n");

end

% read in sole data for 
function sole_data = read_sole_data(subjects, use_manual_trial_borders)

    if nargin < 1 || isempty(subjects)
        subjects = 4:7;
    end

    if nargin < 2 || isempty(use_manual_trial_borders)
        use_manual_trial_borders = true;
    end

    sole_data = struct();

    for i = 1:numel(subjects)
        s = subjects(i);
        sole_data.("s"+s) = read_subject_sole_data(s, use_manual_trial_borders);
    end
end

%% prepare Data for analysis

% analyse step parameters in data
function steps = get_steps(condition_data)
    
    % extract Data
    time  = condition_data.time;
    % right side
    front_r = condition_data.R_front;
    mid_r = condition_data.R_mid;
    heel_r = condition_data.R_heel;
    total_r = condition_data.R_total;
    % left side
    front_l = condition_data.L_front;
    mid_l = condition_data.L_mid;
    heel_l = condition_data.L_heel;
    total_l = condition_data.L_total; 
    
    % initialise structure
    steps = struct();

    steps.right = get_steps_one_side(time, heel_r, mid_r, front_r, total_r);
    steps.left = get_steps_one_side(time, heel_l, mid_l, front_l, total_l);
     
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
        % [max_m ,mim] = max(m);
        [max_f ,mif] = max(f);
        [peakForce, peakIndex] = max(tot);

        % partial force relative to total at maximum
        steps_side(i).heelPropAtMax = max_h / tot(mih);
        steps_side(i).frontPropAtMax = max_f / tot(mif);

        % Rise slope
        dt = mean(diff(t_evt));
        steps_side(i).maxSlope = max(diff(tot)) / dt;

        % start and end of contact
        steps_side(i).start_time = t_evt(1);
        steps_side(i).end_time = t_evt(end);

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

    % classify steps events according to thresholds
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

% analyse trials in the data
function [trials, mean_step_freq, freq_std] = get_trials(condition_data, manual_trial_params)

    % Input: 
    %   trial_data:
    %       struct with:
    %           .data   (table of data, from stamp to turning steps)
    %           .steps  (metadata around data)
    %       Limited to time from stamp to turning steps

    if nargin < 2 || isempty(manual_trial_params)
        manual_trial_params = [];
        % log = "no manual params"
    end

    % Get trial sections
    % generate trial sections
    if isempty(manual_trial_params)

        % stamps to start trials
        stamps_idx = strcmp([condition_data.steps.right.step_type], "stamp");
        n_trials = sum(stamps_idx);
        stamps = condition_data.steps.right(stamps_idx);
        trial_starts = [stamps.peakTime] * 100;

        % turning steps, to end trials
        turning_steps_idx = strcmp([condition_data.steps.right.step_type], "turning");

        % n_turning = sum(turning_steps_idx);
        turning_steps = condition_data.steps.right(turning_steps_idx);
        turning_step_times = [turning_steps.peakTime] * 100;

        % match up stamps and turning steps
        last_trial_end_idx = 1;
        trial_ends = zeros(n_trials, 1);

        exitt = false; % to leave, if no turning steps remain
        for s = 1:n_trials
            t = trial_starts(s);
            while turning_step_times(last_trial_end_idx) < t
                last_trial_end_idx = last_trial_end_idx + 1;
                if last_trial_end_idx == numel(turning_step_times) % no turning steps after stamp
                    exitt = true;
                    break
                end
            end
            if exitt
                trial_starts = trial_starts(1:s-1);
                trial_ends = trial_ends(1:s-1);
                break 
            else
                trial_ends(s) = turning_step_times(last_trial_end_idx);
            end
        end
        n_trials = numel(trial_starts);

    % get manually marked trial sections
    else

        % load saved trial params
        filename = "subject_data\manual_trial_params\" + manual_trial_params(1) + "_" + manual_trial_params(2) + "_trial_times.txt";
        trial_times = jsondecode(fileread(filename));
        n_trials = numel(trial_times);

        % extract indices from struct
        trial_starts = [trial_times.start_time] * 100;
        trial_ends = [trial_times.end_time] * 100;
    end

    % make indices to integers
    trial_starts = round(trial_starts);
    trial_ends = round(trial_ends);

    % initialise return structure
    trials = struct(...
        'start',            {}, ...
        'duration',         {}, ...
        'n_steps',          {}, ...
        'step_period',      {}, ...
        'step_period_std',  {}, ...
        'step_freq',        {}, ...
        'stride_freq',      {} ...
        );
    
    for i = 1:n_trials
        trial_data = condition_data.data(trial_starts(i):trial_ends(i), :);
        trial = analyse_trial(trial_data);
        trials(i) = trial; % Ensure the structure matches
    end

    mean_step_freq = mean([trials.step_freq]);
    freq_std = std([trials.step_freq]);

end

function trial = analyse_trial(trial_data)
    % input: only table of sole data

    % initialise return struct
    trial = struct();

    % get relative time
    trial_time_abs = trial_data.time;
    trial_start_time = trial_time_abs(1);
    trial_end_time = trial_time_abs(end);
    trial_time = trial_time_abs - trial_start_time;
    trial_duration = trial_time(end);

    % get steps for analysis
    trial_steps = get_steps(trial_data);

    % --- Clear data by removing unwanted steps

    % TODO:
    % exclude first step, if diff(1., 2. step) too big
    % exclude steps ongoing at trial end

    % remove steps if in contact at the start
    sides = ["right", "left"];
    for i = 1:numel(sides)
        side = sides(i);
        % check trial start
        if trial_steps.(side)(1).start_time == trial_start_time
            trial_steps.(side) = trial_steps.(side)(2:end);
            % fprintf("Removed " + side + " foot step for contact at the beginning \n");
        end
        % check trial end
        if trial_steps.(side)(end).end_time == trial_end_time
            trial_steps.(side) = trial_steps.(side)(1:end-1);
            % fprintf("Removed " + side + " foot step for contact at the end \n");
        end
    end

    % ----- calculate analytic metrics -----

    % stride frequency
    n_stride_r = numel(trial_steps.right);
    n_stride_l = numel(trial_steps.left);
    n_steps = n_stride_r + n_stride_l;

    stride_freq_r = 60 / mean(diff([trial_steps.right.peakTime]));
    stride_freq_l = 60 / mean(diff([trial_steps.left.peakTime]));
    stride_freq_mean = mean([stride_freq_r * n_stride_r, stride_freq_l * n_stride_l])/ (n_stride_r + n_stride_l);

    % step frequencies
    % combine steps in one array
    all_steps_time = zeros(1, n_steps);
    for sr = 1:n_stride_r
        all_steps_time(sr) = trial_steps.right(sr).peakTime;
    end
    for sl = 1:n_stride_l
        all_steps_time(n_stride_r + sl) = trial_steps.left(sl).peakTime;
    end
    all_steps_time = sort(all_steps_time, 2);

    % calculate freq
    step_diffs = diff(all_steps_time);  % seconds
    step_period = mean(step_diffs);     % Seconds per step
    step_std = std(step_diffs);

    % ----- Outlier removal ------

    % how many stds difference from mean are ok
    tolerance = 1.5;

    % remove from the front
    while abs(step_diffs(1) - step_period) > tolerance * step_std
        % check if still possible
        if numel(step_diffs) < 2
            fprintf("not enough steps left \n")
            break
        end
        step_diffs = step_diffs(2:end);
        fprintf("removed step from the front \n")
    end

    % remove from the back
    while abs(step_diffs(end) - step_period) > tolerance * step_std
        % check if still possible
        if numel(step_diffs) < 2
            fprintf("not enough steps left \n")
            break
        end
        step_diffs = step_diffs(1:end-1);
        fprintf("removed step from the back \n")
    end

    % --------- calculate metrics and add to return struct --------
    
    % recalculate adapted metrics 
    step_period = mean(step_diffs);     % Seconds per step
    step_std = std(step_diffs);

    step_freq = 60 / step_period;       % Steps per minute

    % write attributes in return structure
    trial(1).start = trial_start_time;
    trial.duration = trial_duration;
    trial.n_steps = numel(step_diffs) + 1;
    trial.step_period = step_period;
    trial.step_period_std = step_std;
    trial.step_freq = step_freq;
    trial.stride_freq = stride_freq_mean;


end

% extract trials from Data
function manual_trial_marking(subject, condition)

    % read in data
    cond_data = read_condition_sole_data(subject, condition);
    % plot data for evaluation, mark automated analysis for orientation
    plot_label = "Subject " + subject + " " + condition;
    plot_sole_data(cond_data, true, plot_label);
    trial_times = struct();

    % give mask to enter start and end times

    fprintf("Enter the peak times of the stamp and the first breaking step for each trial \n")

    for idx = 1:20
        
        time = input("Enter Start time: ");
        if isempty(time)
            break
        end
        trial_times(idx).start_time = time;

        time = input("Enter end time: ");
        trial_times(idx).end_time = time;

        fprintf("trials marked: " + idx + "\n")
    end

    % save time stamps
    txt = jsonencode(trial_times);
    
    filename = "subject_data\manual_trial_params\" + subject + "_" + condition + "_trial_times.txt";
    fid = fopen(filename, "w");
    fprintf(fid, "%s", txt);
    fclose(fid);

end

function manually_mark_subject_trials(subject, special_conditions)

    if nargin < 2
        special_conditions = [];
    end

    classical_conditions = ["br", "bvr", "vw", "w", "h", "vh"];

    conditions = cat(2, classical_conditions, special_conditions);

    for i = 1:numel(conditions)
        manual_trial_marking(subject, conditions(i))
    end
end

%% Visualise data 

function plot_sole_data(condition_data, mark_steps, plotLabel)

    % input: 
    %   condition_data: struct with fields :
    %       .data: table of forcesole data
    %       .steps: struct with step parameters. Only needed if mark_steps == true
    %   mark_steps:
    %       boolean, optional. If true, .steps is needed
    %   plot_label:
    %       string, optional

    % ---- Input checks ----
    if nargin < 1 || isempty(condition_data)
        error("Input data must be a non-empty struct with the fields .data and .steps.");
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
    t = data.time;
    R_front = data.R_front;
    R_mid   = data.R_mid;
    R_heel  = data.R_heel;
    R_total = data.R_total;

    L_heel  = data.L_heel;
    L_mid   = data.L_mid;
    L_front = data.L_front;
    L_total = data.L_total;

    % ---- Plot ----
    figure('Name', plotLabel, 'Color', 'w');

    tiledlayout(2,1,"TileSpacing","compact")

    if mark_steps
        % get steps
        steps = condition_data.steps;

        % get step peak times and group by types
        [stamps_r, walking_r, turning_r] = group_steps_by_type(steps.right);
        [stamps_l, walking_l, turning_l] = group_steps_by_type(steps.left);
    end

    % Right foot
    ax1 = nexttile;
    plot(t, [R_heel R_mid R_front R_total], 'LineWidth', 1.2)
    hold on
    if mark_steps 
        plot_step_markers(walking_r, 500, "red", "+");
        plot_step_markers(stamps_r, 550, "magenta", "diamond");
        plot_step_markers(turning_r, 450, "green", "*");
    end
    hold off
    grid on
    title("Right Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

    % Left foot
    ax2 = nexttile;
    plot(t, [L_heel L_mid L_front L_total], 'LineWidth', 1.2)
    hold on
    if mark_steps 
        plot_step_markers(walking_l, 500, "red", "+");
        plot_step_markers(stamps_l, 550, "magenta", "diamond");
        plot_step_markers(turning_l, 450, "green", "*");
    end
    hold off
    grid on
    title("Left Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

    linkaxes([ax1 ax2], "x")
end

function [stamps, walking, turning] = group_steps_by_type(steps_side)
    % Group steps by type (stamp, walking, turning)
    step_times = [steps_side.peakTime];
    step_types = [steps_side.step_type];
    
    stamps = step_times(step_types == "stamp");
    walking = step_times(step_types == "walking");
    turning = step_times(step_types == "turning");
end

function plot_step_markers(step_times, y_pos, color, marker)
    % Plot markers for steps if they exist
    if ~isempty(step_times)
        plot(step_times, y_pos, "Color", color, "Marker", marker);
    end
end

%% Analyse data
% The functions in this section should be called individually, getting prepared data as input.


%% Testing
% clearvars

% d = read_sole_data(4:7);


cd = [read_condition_sole_data(4, "w", true).trials.n_steps]
