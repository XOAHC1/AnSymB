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
    %     Time, R-heel, R-mid, R-front, R-total, Time, L-total, L-front, L-mid, L-heel, Time
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
    R_heel  = data{:,2};
    R_mid   = data{:,3};
    R_front = data{:,4};
    R_total = data{:,5};

    tL = data{:,6};     % Left foot time
    L_total = data{:,7};
    L_front = data{:,8};
    L_mid   = data{:,9};
    L_heel  = data{:,10};

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
    % return array of individual trials, only way there included

    % Notes to stump signal:
    % no rolling pattern
    % slower than step
    % more force in mid-foot than usual
    
    
end

%% Testing

plot_sole_data(3, "h")


