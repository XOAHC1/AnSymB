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

% identify stamps in struct of steps
function stamps = get_stamps(steps, condition_data)

    get_steps_one_side(steps.right, time, right)
end

function stamps_side = get_stamps_one_side(steps_side, time, total)

    nSteps = numel(steps_side);
    
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
        figure; plot(time, total); hold on
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

s_data = read_subject_sole_data(3);

plot_sole_data(s_data.h.data)