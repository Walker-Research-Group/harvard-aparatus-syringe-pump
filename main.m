clear;  % Clear all variables (have to do this between runs otherwise COM port is still in use)

% Establish the connection
p = SyringePump("COM8", 9600);
disp('Connected!')

% Set Syringe diameter to 10mm
p.setDiameter(10);

% Set the rate to 3 ml/m
p.setRate(3, 'ml/m');

% Run forever...
p.resetPumpedVolume();
i = 1;
while true
    % Set to dispense 0.2ml
    p.setTargetVolume(0.2*i);
    p.run();
    disp('run')
    i = i + 1;

    % Wait ten seconds
    pause(10);
end