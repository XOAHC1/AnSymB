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
    %     Time, R-front, R-mid, R-heel, R-total, Time, L-heel, L-mid, L-front, L-total, Time
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

% Read in all sole data
% function complete_sole_data = read_all_sole_data()

%     N_SUBJECTS = 21;
%     complete_sole_data = struct();

%     for s = 1:N_SUBJECTS
%         complete_sole_data.(s) = read_subject_sole_data(s);
%     end
% end

% Analysis functions

function plot_sole_data(subject, condition)
%PLOT_SOLE_DATA Plot sole pressure data for a subject and condition
%
%   plot_sole_data("S01", "br")

    % Read all data for subject
    subject_sole_data = read_subject_sole_data(subject);

    % Check condition exists
    if ~isfield(subject_sole_data, condition)
        error("Condition '%s' does not exist.", condition);
    end

    data = subject_sole_data.(condition);

    % Handle missing / empty data
    if isempty(data)
        warning("No data available for subject %s, condition %s.", subject, condition);
        return
    end

    % ---- Column indices (based on your format) ----
    tR = data{:,1};     % Right foot time
    R_front  = data{:,2};
    R_mid   = data{:,3};
    R_heel = data{:,4};
    R_total = data{:,5};

    tL = data{:,6};     % Left foot time
    L_heel = data{:,7};
    L_mid   = data{:,8};
    L_front  = data{:,9};
    L_total = data{:,10};


    % ---- Plot ----
    figure('Name', subject + " - " + condition, 'Color', 'w');

    tiledlayout(2,1,"TileSpacing","compact")

    % Right foot
    nexttile
    plot(tR, [R_heel R_mid R_front R_total], 'LineWidth', 1.2)
    grid on
    title("Right Foot")
    xlabel("Time")
    ylabel("Pressure")
    legend("Heel","Mid","Front","Total","Location","best")

    % Left foot
    nexttile
    plot(tL, [L_heel L_mid L_front L_total], 'LineWidth', 1.2)
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

    steps = struct([]);
    
    % extract relevant data from data
    t = condition_data{:, 1};
    right = condition_data{:, 5};
    % left = condition_data{:, 10};

    % determin contact phases
    cf = 0.05; % contact factor
    th_r = cf * max(right);
    % th_l = cf * max(left);
    
    r_in_contact = right > th_r;
    % l_in_contact = left > th_l;

    % find connected components in sole data (aka steps)
    r_edges = diff([false; r_in_contact;false]);
    % l_edges = diff([false; l_in_contact; false]);

    % first and Last in contact indices
    r_onsets  = find(r_edges == 1);
    r_offsets = find(r_edges == -1) - 1; 

    % extract steps from data
    nEvents = numel(r_onsets);
            
    for i = 1:nEvents
        idx = r_onsets(i):r_offsets(i);

        t_evt = t(idx);
        heel  = condition_data{idx,2};
        mid   = condition_data{idx,3};
        front = condition_data{idx,4};
        tot   = condition_data{idx, 5};

        % Peak times
        [~,mih] = max(heel);
        [~,mim] = max(mid);
        [~,mif] = max(front);

        steps(i).rolling = ...
            max([t_evt(mih), t_evt(mim), t_evt(mif)]) - ...
            min([t_evt(mih), t_evt(mim), t_evt(mif)]);

        % Rise slope
        dt = mean(diff(t_evt));
        steps(i).maxSlope = max(diff(tot)) / dt;

        % Contact duration
        steps(i).duration = t_evt(end) - t_evt(1);

        % peak time
        [~, peakIndex] = max(tot);
        steps(i).peakTime = t_evt(peakIndex);
    end
end

% identify stamps in struct of steps
function stamps = get_stamps(steps)

    nSteps = numel(steps)
    
    ROLLING_TH = 0.08;   % seconds
    SLOPE_TH   = 3000;   % pressure / s
    DUR_TH     = 0.25;   % seconds

    mark_stamps = true;
    for i = 1:nSteps
        steps(i).isStamp = ...
            steps(i).rolling < ROLLING_TH && ...
            steps(i).maxSlope > SLOPE_TH && ...
            steps(i).duration < DUR_TH;
    end

    if mark_stamps
        figure; plot(t, total); hold on
        for i = 1:nEvents
            if steps(i).isStamp
                xline(t(onsets(i)), 'r', 'LineWidth', 1.5);
            end
        end
    end

end

%% Testing

data = read_condition_sole_data(3, "h");
test = get_steps(data);
% stamps = get_stamps(test);
