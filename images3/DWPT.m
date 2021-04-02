%AUTHOR:    Katherine Kemp (katherine.e.kemp@gmail.com)

function totalCharge = DWPT(V, wireGauge, turns, radius, wireGauge_car, turns_car, radius_car, height, original_spacing, velocity, scenarioID) 
    %% FORMULA Constants

    maxDistance = 16; % distance the car will travel [m] 1600, about 1 mile
    increment = .1; % Resolution (distance between the points in meshgrid) [m] 1/50 pi/4 ~= .78375
    distanceStep = increment; % Distance between timesteps [m] keep equal to increment for best results, or multiply by a positive integer for a more coarse simulation
    
    efficiencyOfRectifier = 1; % We assume the rectifier is perfectly efficient for our simulations []
    muRel = 1; % We assume vacuum permeability in our simulations []
    
    rho = .0171 / 1000^2; % Resistivity of copper [ohm-m]
    wireGauges = [6 8 12]; % Possible wire guages []
    wireDiameters = [.41148 .32639 .20523] / 100; % Corresponding diameters of wire gauges [m] https://ohmslawcalculator.com/awg-wire-chart
    
    dGamma = 1e9; % filament max discretization step [m] found no need to change from provided examples
    filamentStep = 100 * radius; % number of points in the each turn of the filament [1/m]
    tightness = 10000; % Increasing tightness will make the coil wrapped more tightly [1/m] We want them to be wrapped perfectly tightly, and this appears to be close enough.
    tightness_car = 10000; % Increasing tightness will make the coil wrapped more tightly [1/m] We want them to be wrapped perfectly tightly, and this appears to be close enough.

    %% Initialize
    
    tic %  Start counting time
    plot_scrsz = get(groot,'ScreenSize'); % Make graphs the screen size
    
    spacing = 2 * radius + original_spacing;
    d = wireDiameters(find(wireGauges == wireGauge)); % Wire diameter corresponding to gauge [m]
    A = pi * d^2 / 4; % Cross sectional area [m^2]
    L = 2 * pi * radius * (turns + 1); % Length of a coil [m], we assume the wire beyonf the coil to be negligible in comparison but add one extra loop to get a closer estimate
    R = rho * L / A; % Resistance of a coil [ohms]
    I = V / R; % Currentin road [A]
    
    d_car = wireDiameters(find(wireGauges == wireGauge_car)); % Wire diameter corresponding to gauge [m]
    A_car = pi * d_car^2 / 4; % Cross sectional area [m^2]
    L_car = 2 * pi * radius_car * (turns + 1); % Length of a coil [m], we assume the wire beyonf the coil to be negligible in comparison but add one extra loop to get a closer estimate
    R_car = rho * L_car / A_car; % Resistance of a car coil [ohms]
    
    distance = 0:distanceStep:maxDistance; % Make distance array the max distance - the car coil (so it doesn't go off the page)
    time = distance./velocity; % Corresponding time array
    
    flux = zeros(1, length(distance)); % [C] Initialize flux array
    BSmag.Nfilament = 0; % Initialize number of source filament (from BSmag_init)

    %% Initialize videos
    
    filename1 = sprintf('dataComp/Scenario%u', scenarioID);
    myVideo1 = VideoWriter(filename1, 'MPEG-4'); % open video file
    myVideo1.FrameRate = 10;  % can adjust this, 5 - 10 works well for me
    open(myVideo1)

    filename2 = sprintf('dataComp/Sideview%u', scenarioID);
    myVideo2 = VideoWriter(filename2, 'MPEG-4'); % open video file
    myVideo2.FrameRate = 10;  % can adjust this, 5 - 10 works well for me
    open(myVideo2)
    
    %% Create Filaments
    
    Gamma = [];
    coilCount = floor((maxDistance - radius) / spacing + 1) + 1;
    sign = 1;
    for x = 0:coilCount % Change to 1?
        theta = linspace(0, turns*2*pi, turns*filamentStep); % Source points (points where there is a current source)
        Gamma = [cos(theta')*radius + radius + x * spacing, sin(theta') * radius, theta'/tightness]; % x,y,z
        [BSmag] = BSmag_add_filament(BSmag,Gamma,sign*I,dGamma); %% populate BSmag data structure
        sign = -sign;
    end
    
    %% Place vector field
    % Field points (where we want to calculate the field)
    
    maxRadius = max(radius,radius_car);
    numberOfSquaresX = 1 + maxDistance / increment; % Calculate the number of squares on the mesh X
    numberOfSquaresY = 1 + 2*maxRadius / increment; % Calculate the number of squares on the mesh Y
    numberOfSquaresZ = 7; % Calculate the number of squares on the mesh Z
    x_M = linspace(0, maxDistance + 2*maxRadius, numberOfSquaresX + 2*maxRadius / increment + 1); % x [m]
    y_M = linspace(-maxRadius, maxRadius, numberOfSquaresY); % y [m]
    z_M = linspace(height - 3.5 * increment, height + 3.5 * increment, numberOfSquaresZ); % z [m]
    [X_M,Y_M,Z_M]=meshgrid(x_M,y_M,z_M);
    heightIndex = .5 + numberOfSquaresZ / 2;
    
    %% Biot-Savart Integration
    
    [X,Y,Z,BZ] = BSmag_get_B(BSmag,X_M,Y_M,Z_M,muRel); %% This is where the integation happens
    BZ(abs(BZ)<1e-10) = 0; % Make tiny values equal to 0
    BZlimits = [min(min(BZ(:,:,heightIndex))) max(max(BZ(:,:,heightIndex)))]; % get [minBZ maxBZ]
    
    %% Simulation
    for i=1:length(distance)
        %% Calculate current flux and total charge
        
        minX = distance(i) * numberOfSquaresX / maxDistance; % index in the mesh grid of the minimum x value of the car coil
        field = zeros(numberOfSquaresY, numberOfSquaresY); % initialize flux array to zeros

        for n = round(minX)+1:round(minX)+numberOfSquaresY % Integration accross x
            yLim = sqrt(radius_car^2 - (X_M(1,n) - radius_car - distance(i))^2); % The limits in each row of meshgrid for the y values (so we ignore values outside of the car coil and set them to zero)
            for m = 1:numberOfSquaresY % Integration across y
                if Y_M(m,1) > -1*yLim & Y_M(m,1) < yLim % If the element is within the y limits
                    field(m, n - round(minX)) = BZ(m,n,heightIndex); % put BZ of that location in the field array, we only care about BZ because it is perpendicular
                end
            end
        end

        flux(i) = trapz(Y_M(:,1)',trapz(X_M(1,round(minX)+1:round(minX)+numberOfSquaresY),field,2)); % Integrate field of x and then over y to get total flux at that location

        %% Car filament for plots
        
        theta_car = linspace(0, turns_car*2*pi, turns_car*filamentStep);
        Gamma_car = [cos(theta_car')*radius_car + radius_car + distance(i), sin(theta_car')*radius_car, theta_car'/tightness_car + height]; % x,y,z

        %% FIGURE Visualize surface
        
        f1 = figure(1);
        f1.OuterPosition = [1.5*plot_scrsz(3) .2*plot_scrsz(4) .6*plot_scrsz(3) .7*plot_scrsz(4)];
        hold on, box on, grid on
        xlim([0, maxDistance + 2*maxRadius]);
        for n=1:BSmag.Nfilament % Plot all filaments in road in black
            plot3(BSmag.filament(n).Gamma(:,1),BSmag.filament(n).Gamma(:,2),BSmag.filament(n).Gamma(:,3),'.-k') % plot filament
        end
        slice(X,Y,Z,BZ,[],[],[height]), colorbar % plot Bz at heigh of the car coil
        plot3(Gamma_car(:,1),Gamma_car(:,2),Gamma_car(:,3),'.-r') % plot car filament in red
        xlabel ('x [m]'), ylabel ('y [m]'), zlabel ('z [m]'), title ('Bz [T] 3D Road View')
        daspect([1,1,1])
        view(3) % Show 3D view
        caxis([-.5 .5])
        drawnow
        pause(.4)

        frame1 = getframe(gcf); % Get frame
        writeVideo(myVideo1, frame1); % Add frame to the video
        clf
        hold off
        
        %% FIGURE Visualize surface (side view)
        
        f2 = figure(2);
        f2.OuterPosition = [ 1.5*plot_scrsz(3) .2*plot_scrsz(4) .6*plot_scrsz(3) .7*plot_scrsz(4)];
        hold on, box on, grid on
        xlim([0, maxDistance + 2*maxRadius]);
        for n=1:BSmag.Nfilament % Plot all filaments in road in black
            plot3(BSmag.filament(n).Gamma(:,1),BSmag.filament(n).Gamma(:,2),BSmag.filament(n).Gamma(:,3),'.-k') % plot filament
        end
        slice(X,Y,Z,BZ,[],[0],[]), colorbar % plot Bz at center of road coils from the sideview
        plot3(Gamma_car(:,1),Gamma_car(:,2),Gamma_car(:,3),'.-r') % plot car filament in red
        xlabel ('x [m]'), ylabel ('y [m]'), zlabel ('z [m]'), title ('Bz [T] Side View')
        daspect([1,1,1])
        view(0,0) % Show the desired side view
        caxis([-.5 .5])
        drawnow
        pause(.4)

        frame2 = getframe(gcf); % Get frame
        writeVideo(myVideo2, frame2); % Add frame to the video
        clf
        hold off
        
    end

    close(myVideo1)
    close(myVideo2)
    
    dT = diff(time);
    inducedEMF = -turns_car*diff(flux)./dT;
    I_car = inducedEMF./R_car;
    totalCharge = trapz(time(1:length(I_car)),efficiencyOfRectifier*abs(I_car));
    cumulativeCharge = cumtrapz(time(1:length(I_car)),efficiencyOfRectifier*abs(I_car));
    
    f3 = figure(3);
        hold on
        plot(time(1:length(I_car)),I_car)
        xlabel ('time [s]'), ylabel ('Current [A]'), title ('Current vs. Time')
        saveas(f3,sprintf('dataComp/currentVStime%u.jpg',scenarioID))
        hold off
        
    f4 = figure(4);
        hold on
        plot(time(1:length(cumulativeCharge)),cumulativeCharge)
        xlabel ('time [s]'), ylabel ('Cumulative Charge [C]'), title ('Cumulative Charge vs. Time')
        saveas(f4,sprintf('dataComp/cumChargeVStime%u.jpg',scenarioID))
        hold off
        
    close all
    toc % print time elapsed
end