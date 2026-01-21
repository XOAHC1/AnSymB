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

    subject_data_path = SOLE_DATA_PATH + "\" + subject;
    data_path = subject_data_path + "\" + condition +".txt";

    condition_sole_data = readtable(data_path);

end

% Read in sole data from all trials by one subject
function subject_sole_data = read_subject_sole_data(subject)
end

% Read in all sole data
function complete_sole_data = read_all_sole_data()
end

% Analysis functions
% get individual trials
function trials = seperate_trials(condition_sole_data)
    % return array of individual trials, only way there included
end

