sole_data_path = "subject_data\sole-data";
vr_data_path = "subject_data\vr_data";

n_subjects = 21;
subject = 2;

% subject_sole_data = importdata(sole_data_path + "\" + subject + "\loadapp_2025-12-09_11-14-25-548.load_ASCII");

% print(subject_sole_data)

test = importdata("subject_data\sole-data\1\loadapp_2025-12-09_11-03-20-499.load_ASCII.txt").textdata;

condition = test(2)
