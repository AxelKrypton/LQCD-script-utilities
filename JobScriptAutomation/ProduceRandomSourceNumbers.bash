#!/bin/bash
#
#  Copyright (c) 2015 Christopher Czaban
#
#  This file is part of "Script utilities".
#
#  "Script utilities" is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  "Script utilities" is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with "Script utilities". If not, see <http://www.gnu.org/licenses/>.
#



ls | grep "conf\.[[:digit:]]\{5\}" | awk '
BEGIN{
        maxNrCorrs = 8;
        nt = 32;
        ns = 16;
        srand();
}
{
    split($1,corr_name_array,"_");
    conf_count[corr_name_array[1]]++;
    if(corr_name_array[2] != "")
    {
        conf_x_y_z_t_corr_key[$1];
    }
}
END{
    for(conf_nr in conf_count)
    {
        while(conf_count[conf_nr] <= maxNrCorrs)
        {
            coordinates = int(rand()*ns) "_" int(rand()*ns) "_" int(rand()*ns) "_" int(rand()*nt) "_" "corr";
            new_corr_name = conf_nr "_" coordinates;
            #print new_corr_name;
            if(new_corr_name in conf_x_y_z_t_corr_key == 0)
            {
                conf_x_y_z_t_corr_key_new[new_corr_name];
                conf_count[conf_nr]++;
            }
        }
    }

    n = asorti(conf_count, conf_count_sorted);
    for(i = 1; i <= n; ++i)
    {
       for(j in conf_x_y_z_t_corr_key_new)
       {
           if(match(j,conf_count_sorted[i]))
           {
               split(j,corr_name_array,"_");
               print "--sourcefile=" conf_count_sorted[i] " --source_x=" corr_name_array[2] " --source_y=" corr_name_array[3] " --source_z=" corr_name_array[4] " --source_t=" corr_name_array[5];
           }
       }
    }
}'
