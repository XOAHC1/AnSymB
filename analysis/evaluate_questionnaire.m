
clearvars
qd = readtable("subject_data\questionaire\data_pedestrian_synchronisation_2026-02-02_15-46.csv");
age = qd.Age_D001_01;
crowd_effect = qd.NPC_Influence_IN01 - 4;
cramped = qd.Cramped_IN02 - 1;
response = qd.NPC_Attention_IN03 - 4;
any_effect = qd.Percieved_Influence_IN04 - 1;


idcs = [4:13, 15:21] - 1;

affected = mean([cramped(idcs)])
cramped = mean([crowd_effect(idcs)])
response = mean([response(idcs)])
effect = mean([any_effect(idcs)])