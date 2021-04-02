%AUTHOR:    Katherine Kemp (katherine.e.kemp@gmail.com)

function data = main(outputFolder)  
    outputFolder = 'maxOutput';
    warning('off');

    %% FORMULA variables
    
    % Transmitting coil
    V = [600]; % Voltage of solar panels [V]
    wireGauge = [6]; % Wire gauge []
    turns = [510]; % Number of turns in the coil []
    radius = [1]; % Radius of transmitting coil [m]

    % Receiving coil
    wireGauge_car = [8]; % Wire gauge []
    turns_car = [320]; % Number of turns in the coil []
    radius_car = [1.5]; %  Radius of receiving coil [m]

    % Coil orientation
    height = [.15]; % Height of the receiving coil above the transmitting coil [m]
    spacing = [.09]; % Distance betewen closest edges of coils in road [m]
    velocity = [30]; % Velocity of car [m/s]

    %% MAIN

    totalScenarios = length(V) * length(wireGauge) * length(turns) * length(radius) * length(radius_car) * length(height) * length(spacing);
    [A, B, C, D, E, F, G] = ndgrid(V, wireGauge, turns, radius, radius_car, height, spacing);

    A = reshape(A, [1, totalScenarios]);
    B = reshape(B, [1, totalScenarios]);
    C = reshape(C, [1, totalScenarios]);
    D = reshape(D, [1, totalScenarios]);
    E = reshape(E, [1, totalScenarios]);
    F = reshape(F, [1, totalScenarios]);
    G = reshape(G, [1, totalScenarios]);
    
    mkdir(outputFolder);
    name = strcat(outputFolder, '/out.txt');
    fid = fopen(name, 'w');
    fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', 'scenarioID []', 'i []', 'V [V]', 'wireGauge []', 'turns []', 'radius [m]', 'wireGauge_car []', 'turns_car []', 'radius_car [m]', 'height [m]', 'spacing [m]', 'velocity [m/s]', 'totalCharge [C]', 'cost [$]', 'cost/charge [$/C]');
    fclose(fid);
    
    data =  []; % Initialize data matrix
    format shortG % print data with the desired detail
    mod_val = round(totalScenarios/100);
    parpool();

    for i = 1 : totalScenarios
        tic
        fid = fopen(name, 'a');
        returnData = get_field(A(i), B(i), C(i), D(i), wireGauge_car, turns_car, E(i), F(i), G(i), velocity, i, outputFolder);
        data = [data; returnData];
        
        for j = 1:length(returnData(:,1))
            for k = 1:length(returnData(j,:))
                fprintf(fid, "%d,", returnData(j, k));
            end
            fprintf(fid, "\n");
        end
        
        if mod(i, mod_val) == 0
            sprintf('%d percent done, i = %d out of %d', round(100*i/totalScenarios), i, totalScenarios)
        end
        toc
    end

    writematrix(data, 'backup.csv')
    delete(gcp('nocreate'))
    fclose('all');
end