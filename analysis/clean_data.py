import os
import numpy as np

dir = "..\subject_data\sole-data"
subjects = np.array(range(1, 21))

for s in subjects:
    sdir = dir + f"\{s}"

    # print(sdir)
    for file in os.scandir(sdir):
        filename = file.path

        name = os.fdopen(filename)

        print(name)
