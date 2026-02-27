%% Define Functions
% clearvars

CONDITIONS = ["br", "bvr", "vw", "w", "h", "vh"];

%% Read in Data

% Read in sole data for one condition by one subject
function condition_sole_data = read_condition_sole_data(subject, condition, manual_trials, further_analysis)

    % Data Format:
    %     1   , 2     , 3     , 4     , 5     , 6     , 7     , 8     , 9     , 10    , 11
        % Time, R-front, R-mid, R-heel, R-total, Time, L-heel, L-mid, L-front, L-total, Time
    % 
    % Data is also accessable by collumn headers. Thoose change depending on the soles used, therefore access via index is to be preferred.

    if nargin < 3 || isempty(manual_trials)
        manual_trials = false;
    end
    if nargin < 4 || isempty(further_analysis)
        further_analysis = true;
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
    condition_sole_data.experiment_time = dt;
    condition_sole_data.steps = get_steps(data);

    if further_analysis
        [condition_sole_data.trials, ...
        condition_sole_data.mean_step_freq, ...
        condition_sole_data.std_step_freq, ...
        condition_sole_data.mean_peak_force, ...
        condition_sole_data.peak_force_std, ...
        ] = get_trials(condition_sole_data, manual_trial_params);
    end


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
        subjects = 4:13;
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

% Read in HMD Data (one condition)
function [mean_vel, mean_acc, max_vel, max_acc, hmd_data] = read_condition_hmd_data(subject, condition, choosen_trials)

    if nargin < 3 || isempty(choosen_trials)
        % set to 10 to get only "uncrashed" conditions, 20 to get all
        choosen_trials = 10;
    end

    % Read Data
    hmd_data = struct();
    DataPath = "subject_data\vr_data\" + subject + "\";
    filename = sprintf('%i_%s_experiment.csv', subject, condition);

    data = readmatrix(DataPath + filename);

    % get first analysis
    trial_number = data(:, 2);
    
    for i = 1:choosen_trials
        idcs = trial_number == i;
        if sum(idcs) == 0
            continue
        end
        trial = data(idcs, :);

        trial_result = analyse_hmd_trial(trial);
        
        hmd_data.trial_data(i) = trial_result;
    end

    % Write results
    mean_vel = mean([hmd_data.trial_data.mean_vel]);
    mean_acc = mean([hmd_data.trial_data.mean_acc]);
    max_vel = max([hmd_data.trial_data.max_speed]);
    max_acc = max([hmd_data.trial_data.max_acc]);


end

% Read in HMD Data (one subject)
function hmd_data = read_subject_hmd_data(subject)

    HMD_CONDITIONS = ["Baseline", "very weak", "weak", "heavy", "very heavy"];
    CONDITIONS = ["bvr", "vw", "w", "h", "vh"];

    hmd_data = struct();
    hmd_data.conditions = struct([]);

    for cond_idx = 1:numel(HMD_CONDITIONS)
        [hmd_data.conditions(cond_idx).mean_vel, ...
        hmd_data.conditions(cond_idx).mean_acc, ...
        hmd_data.conditions(cond_idx).max_vel, ...
        hmd_data.conditions(cond_idx).max_acc, ...
        hmd_data.(CONDITIONS(cond_idx))] = read_condition_hmd_data(subject, HMD_CONDITIONS(cond_idx));
    end

end

% read all hmd data
function hmd_data = read_hmd_data(subjects)

    if nargin < 1
        subjects = 4:21;
    end

    hmd_data = struct();

    for s = 1:numel(subjects)
        hmd_data.("s"+subjects(s)) = read_subject_hmd_data(subjects(s));
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
function [trials, mean_step_freq, freq_std, mean_peak_force, peak_force_std] = get_trials(condition_data, manual_trial_params)

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

        try
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
        catch ME 
            n_trials = 0;
            trial_starts = [];
            trial_ends = [];
        end

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
        'mean_peak_force',      {}, ...
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
    
    mean_step_freq = sum([trials.step_freq] .* [trials.n_steps]) / sum([trials.n_steps]);
    freq_std = std([trials.step_freq]);
    mean_peak_force = sum([trials.mean_peak_force] .* [trials.n_steps]) / sum([trials.n_steps]);
    peak_force_std = std([trials.mean_peak_force]);
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

    % remove steps if in contact at the start
    sides = ["right", "left"];
    for i = 1:numel(sides)
        side = sides(i);
        if numel(trial_steps.(side)) < 2
            break
        end
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
    TOLERANCE = 2;

    % remove from the front
    while numel(step_diffs) > 1 && abs(step_diffs(1) - step_period) > TOLERANCE * step_std
        % check if still possible
        if numel(step_diffs) < 2
            fprintf("not enough steps left \n")
            break
        end
        step_diffs = step_diffs(2:end);
        fprintf("removed step from the front \n")
    end

    % remove from the back
    while ~isempty(step_diffs) & abs(step_diffs(end) - step_period) > TOLERANCE * step_std
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
    
    step_freq = 1 / step_period;       % Steps per minute

    % peak forces
    
    mean_peak_force = mean(cat(2, [trial_steps.right.peakForce], [trial_steps.left.peakForce]));


    % write attributes in return structure
    trial(1).start = trial_start_time;
    trial.duration = trial_duration;
    trial.mean_peak_force = mean_peak_force;
    trial.n_steps = numel(step_diffs) + 1;
    trial.step_period = step_period;
    trial.step_period_std = step_std;
    trial.step_freq = step_freq;

    trial.stride_freq = stride_freq_mean;

end

% extract trials from Data
function manual_trial_marking(subject, condition)

    % read in data
    cond_data = read_condition_sole_data(subject, condition, false, false);
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

function manually_mark_subject_trials(subject, special_conditions, skip_conditions)

    if nargin < 2 || isempty(special_conditions)
        special_conditions = [];
    end
    if nargin < 3 || isempty(skip_conditions)
        skip_conditions = [];
    end

    classical_conditions = ["vh"];

    conditions = cat(2, classical_conditions, special_conditions);

    if ~isempty(skip_conditions)
        conditions = conditions(~contains(conditions, skip_conditions));
    end

    for i = 1:numel(conditions)
        manual_trial_marking(subject, conditions(i))
    end
end

% analyse hmd data
function trial_result = analyse_hmd_trial(trial)
    trial_result = struct();

    % remove start (by moving)
    raw_pos_x = trial(:, 3);
    start_pos_x = min(raw_pos_x);
    end_pos_x = max(raw_pos_x);

    goal_radius = 0.20;          %m

    close_to_start = diff([abs(raw_pos_x - start_pos_x) > goal_radius]);
    close_to_end = diff([abs(raw_pos_x - end_pos_x) < goal_radius]);

    walking_start = find(close_to_start, 1, "last");
    walking_end = find(close_to_end, 1, "first");

    idcs = walking_start:walking_end;
    % idcs = abs(raw_pos_x - start_pos_x) > goal_radius;
    if numel(idcs) < 100
        n_timesteps = sum(idcs)
    end
    trial = trial(idcs, :);

    % retrieve relevant data
    time_stamp = trial(:, 1);
    dt = diff(time_stamp);

    pos_x = trial(:, 3);
    pos_y = trial(:, 5);

    diff_x = diff(pos_x);
    diff_y = diff(pos_y);

    vel = sqrt(diff_x .^2 + diff_y .^2) ./ dt;       % m/s
    acc = diff(vel) / mean(dt);                     % m/s^2

    % write results
    trial_result.mean_vel = mean(vel);
    trial_result.max_speed = max(vel);
    trial_result.max_acc = max(abs(acc));
    trial_result.mean_acc = mean(abs(acc));

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

% visualise hmd data
% @param hmd_data: top level, i.e. Layers for subjects and conditions
function visualise_velocity(subjects, hmd_data)

    if nargin < 2 || isempty(hmd_data)
        hmd_data = read_hmd_data(subjects);
    end

    NSUBJECTS = numel(subjects);
    NCONDITIONS = 5;

    velocities = zeros(NSUBJECTS, NCONDITIONS);
    accelerations = zeros(NSUBJECTS, NCONDITIONS);

    for s_idx = 1:NSUBJECTS
        s_data_conds = hmd_data.("s"+subjects(s_idx)).conditions;
        velocities(s_idx, :) = [s_data_conds.mean_vel];
        accelerations(s_idx, :) = [s_data_conds.mean_acc];
    end

    % --- plot absolute Velocities

    y_data = velocities';
    x_labels = ["bvr", "vw", "w", "h", "vh"];
    ers = [];
    fig_title = "Velocity-in-conditions";
    xl = "Conditions";
    yl = "velocity [m/s]";

    create_bar_plot(subjects, y_data, x_labels, ers, fig_title, xl, yl);

    % Relative deviation from Baseline
    dev = ((velocities - velocities(:, 1)) ./ velocities(:, 1)) * 100; % [%]

    y_data = dev';
    fig_title = "Relative-Velocity-Deviation";
    yl = "vel Deviation from the Baseline relative [%]";

    create_bar_plot(subjects, y_data, x_labels, ers, fig_title, xl, yl);
    
    % plot mean Deviation from Baseline (relative)

    if isempty(dev)
        log = "empty dev: "
    end

    y_data = mean(dev)';
    ers = std(dev)';
    fig_title = "Average-Relative-Velocity-Deviation";


    create_bar_plot("mean", y_data, x_labels, ers, fig_title, xl, yl);
        
end


%% Analyse data
% The functions in this section should be called individually, getting prepared data as input.

% step_freq development over trials (in condition)
function step_freq_adaptation = step_freq_adaptation_trials(subject, d, visualise, conditions)

    % callable for one subjects and conditions
    % default: all 'save' ones, all conditions
    % return struct:
    %   .condition
    %       .trials             step_freq in jedem trial
    %       .mean               mean_step_freq der condition
    %       .std                step_freq_std
    %       .adaptation         step_freq_difference to the next trials
    %       .adaptation_mean    mean adaptation between trials
    %       .adaptation_std     standard deviation (adaptaion)
    %       .deviation          difference to the mean
    %   .mean                   mean step_freq of the subject



    if nargin < 1 || isempty(subject)
        subject = 4;
    end

    if nargin < 2 || isempty(d)
        % --- get Data---
        d = read_subject_sole_data(subject, true);
    end
    
    if nargin < 3 || isempty(visualise)
        visualise = false;
    end

    if nargin < 4 || isempty(conditions)
        conditions = ["br", "bvr", "vw", "w", "h", "vh"];
    end


    % --- extract Data for subjects and conditions
    for c_idx = 1:numel(conditions)
        c = conditions(c_idx);
        
        % extract step_freqs
        c_step_freqs = [d.(c).trials.step_freq];
        
        % Calculate adaptation metrics
        adaptation = diff(c_step_freqs);

        % write return structure       
        step_freq_adaptation.(c).condition = c;
        step_freq_adaptation.(c).trials = c_step_freqs;
        step_freq_adaptation.(c).mean = mean(c_step_freqs);
        step_freq_adaptation.(c).std = std(c_step_freqs);
        step_freq_adaptation.(c).adaptation = adaptation;
        step_freq_adaptation.(c).adaptation_mean = mean(adaptation);
        step_freq_adaptation.(c).adaptation_std = std(adaptation);
        step_freq_adaptation.(c).deviation_from_mean = c_step_freqs - mean(c_step_freqs);
    end
    
    % Collect all trial frequencies across conditions
    all_trials = [];
    for c_idx = 1:numel(conditions)
        all_trials = [all_trials, step_freq_adaptation.(conditions(c_idx)).trials];
    end
    step_freq_adaptation.mean_step_freq = mean(all_trials);
   
end

% step_freq development over crowd density
function step_freq_adaptation_conditions(subjects, d, visualise)
    
        % return struct:
        %   matrix with dims: 
        %       subjects, conditions, params
        %   Params: 
        %       sequence, msfs, stds
        %   sort trials by sequence or NPC density


    % ---- handle inputs -------
            if nargin < 1 || isempty(subjects)
                subjects = 4;

            end

            if nargin < 2 || isempty(d)
                d = read_sole_data(subjects, true);
            end

            if nargin < 3 || isempty(visualise)
                visualise = false;
            end

    % ---- content -------
        % initialise return struct

    
    % 
    conditions = ["br", "bvr", "vw", "w", "h", "vh"];
    n_conditions = numel(conditions);
    n_subjects = numel(subjects);

    % return matrix
    params = zeros(n_subjects, n_conditions, 11);

    for s_idx = 1:n_subjects
        s = subjects(s_idx);
        % get subject data
        sd = d.("s"+s);
        bl_step_freq = sd.bvr.mean_step_freq;
        bl_peak_force = sd.bvr.mean_peak_force;

        % for each condition, get step_freq, std in condition, difference to mean
        for c_idx = 1:n_conditions
            cond = conditions(c_idx);

            % save params
            params(s_idx, c_idx, :) = [...
                sd.(cond).place_in_sequence, ... % sequence
                c_idx, ...
                sd.(cond).mean_step_freq, ...    % msf
                sd.(cond).std_step_freq, ...     % ssf
                sd.(cond).mean_step_freq - bl_step_freq, ...
                subjects(s_idx), ...
                sd.(cond).mean_peak_force, ...
                sd.(cond).peak_force_std, ...
                sd.(cond).mean_peak_force - bl_peak_force, ...
                mean([sd.(cond).trials.n_steps]), ...
                std([sd.(cond).trials.n_steps]), ...
            ];

        end
    end

    if visualise
        % t = "aufgerufen"
        visualise_adaptation(params);
    end

end

% visualise step_freq adaptation to scenarios. 
% params: matrix, (:, 1) -> conditions, (:, 2) -> sfs
function visualise_adaptation(params)

    % define constants
    conditions = ["br", "bvr", "vw", "w", "h", "vh"];
    n_conditions = numel(conditions);
  
    % retrieve data
        seq = params(:, :, 1);                      % Sequence 
        conds = conditions(params(:, :, 2));        % conditions
        msfs = params(:, :, 3);                     % mean step frequencies
        stds = params(:, :, 4);                     % standard deviation sf
        divergence = params(:, :, 5);               % absolute sf divergence from base line vr
        subjects = params(:, 1, 6);                 % subjects 
        mpf = params(:, :, 7);                      % mean peak force
        pfstd = params(:, :, 8);                    % standard deviation of mean peak forces over trials in condition
        pf_divergence = params(:, :, 9);            % absolute peak force divergence from baseline
        steps_per_trial = params(:, :, 10);         % average n_steps per trial in condition
        std_steps_per_trial = params(:, :, 11);     % standard deviation of n_steps over trials in condition

    
    %  -------------- Plots --------------
     % --- grouped by condition, split by subject
        fig_title = "Step-Frequencies-by-condition";
        data = msfs';
        ers = stds';
        xl = "Condition";
        yl = "Mean Step Frequency [Hz]";

        create_bar_plot(subjects, data, conds', ers, fig_title, xl, yl)

     % -------- divergence from baseline relative to mean (%)
        fig_title = "Relative-Step-Frequency-Divergence";
        baselines = repmat(msfs(:, 2), 1, n_conditions);
        rel_data = (divergence' ./ baselines') * 100;
        yl = "step frequency divergence from baseline [% of baseline]";


        create_bar_plot(subjects, rel_data, conds', [], fig_title, xl, yl)

     % --- divergence from bl relative to mean, mean over subjects
        fig_title = "Mean-Relative-Step-Frequency-Divergence";
        d = mean(rel_data, 2);
        c = conds(1, :);
        s = std(rel_data, 0, 2);

        create_bar_plot("mean", d, c, s, fig_title, xl, yl);

     % sort sf data by sequence
        [~, idcs] = sort(seq');
        cols = repmat(1:size(rel_data,2), size(rel_data,1), 1);
        seq_data = rel_data(sub2ind(size(rel_data), idcs, cols));
        
     % ---- divergence, sorted by sequence ----
        fig_title = "Mean-Relative-Step-Frequency-Divergence-by-Sequence"; 
        d = mean(seq_data, 2);
        s = std(seq_data, 0, 2);
        xl = "Place in Sequence";

        create_bar_plot("mean", d, 1:numel(d), s, fig_title, xl, yl);

     % ----- peak forces -----
        fig_title = "Peak-Forces";
        d = mpf';
        s = pfstd';
        xl = "Conditions";
        yl = "Peak Forces";

        create_bar_plot(subjects, d, c, s, fig_title, xl, yl)

    %  % ----- rel peak force STDs ----
    %     fig_title = "Peak-Force-std";
    %     d =  mean((pfstd ./ mpf));
    %     s = [];
    %     yl = "Standard Deviation Relative to Value";

    %     create_bar_plot(subjects, d, c, s, fig_title, xl, yl)

     % ----- relative pf deviation
        pf_baselines = repmat(mpf(:, 2), 1, n_conditions);
        pf_rel_data = (pf_divergence' ./ pf_baselines') * 100;

        fig_title = "Relative-Peak-Force-Deviation";
        d = pf_rel_data;
        s = [];
        yl = "Relative Peak Force Deviation [% baseline]";

        create_bar_plot(subjects, d, c, s, fig_title, xl, yl)

     % -- mean relative pf deviation
        fig_title = "Average-Peak-Force-Deviation";
        d = mean(pf_rel_data, 2);
        s = std(pf_rel_data, 0, 2);

        create_bar_plot("mean", d, c, s, fig_title, xl, yl)

     % -- steps per trial
        fig_title = "Steps-per-Trial";
        d = steps_per_trial';
        c = conds';
        s = std_steps_per_trial';
        
        xl = "Condition";
        yl = "Average Steps per trial";

        create_bar_plot(subjects, d, c, s, fig_title, xl, yl)  

     % -- create average 
        bl_steps = steps_per_trial(:, 2);
        relative_step_dev = (steps_per_trial ./ bl_steps - 1) * 100;

     % -- average relative deviation n_steps
        fig_title = "Average-Deviation-Steps-per-Trial";
        d = mean(relative_step_dev)';
        s = std(relative_step_dev, 0, 1)';
        yl = "Average Deviation n Steps [% of baseline]";

        create_bar_plot("mean", d, c, s, fig_title, xl, yl)

end

function create_bar_plot(subjects, data, x_labels, ers, fig_title, xl, yl)
    
    save = false;

    error_bars = true;
    if nargin < 4 || isempty(ers)
        error_bars = false;
    end
    if nargin < 5
        fig_title = "generic title";
    end

    n_subjects = numel(subjects);

    fig = figure("Name", fig_title);
    b = bar(data);
    grid("on")

    if error_bars
        hold on
        x = [];
        for s = 1:n_subjects
            x = [x ; b(s).XEndPoints];
        end
        errorbar(x', data, ers, "k", "LineStyle", "none")
        hold off
    end

    xticklabels(x_labels)
    xlabel(xl)
    ylabel(yl)

    % remove legend if inpractical
    if n_subjects > 1 && n_subjects < 12
    legend("s "+ string(subjects), 'Location', 'southoutside', 'Orientation', 'horizontal', 'NumColumns', 5);
    end

    title(fig_title)

    if save
        filename = "figures\" + fig_title + ".jpg";
        exportgraphics(fig, filename);
    end
end

function show_analysis(subjects, sd)
    
    if nargin < 1 || isempty(subjects)
        subjects = 4:13;
    end

    if nargin < 2 || isempty(sd)
        sd = read_sole_data(subjects, true);
    end

    % show sole data
    step_freq_adaptation_conditions(subjects, sd, true);

    % show hmd_data
    visualise_velocity(subjects)
end

    
% S 14 Is not save for analysis
%% Testing
% clearvars

% sd = read_sole_data([4:13, 15:21], true);
show_analysis([4:13, 15:21], sd)

% visualise_velocity([4:13, 15:21])