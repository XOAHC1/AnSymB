sole_data_path = "subject_data\sole-data";
vr_data_path = "subject_data\vr_data";

n_subjects = 21;
subject = 3;
conditions = ["br", "bvr", "vw", "w", "h", "vh"];
condition = "br";

subject_data_path = sole_data_path + "\" + subject;

% for condition = conditions
%     data_path = subject_data_path + "\" + condition +".txt";
%     data = readtable(data_path);
% end


data_path = subject_data_path + "\" + condition +".txt";
T = readtable(data_path);

time = T{:, 1};
right_total = T{:, 5};
left_total = T{:, 7};

plot(time, [right_total, left_total])