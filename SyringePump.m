%  Author: Samuel Ryckman
%  Date: July 25, 2020
% 
%  Class for controlling the Harvard Apparatus Model 22 Multisyringe 
% (MA1 55-5920). The pump has a serial interface which allows it to be
% controlled. 
% 
% Creating the class:
%   obj = SyringePump(comPort, baudRate)
% 
% Inputs: 
%         comPort = port the pump is connected to. Can use seriallist()
%               to get a list of connected ports.
%         baudRate = baud rate for the connection. Can be 300, 1200, 2400 
%               or 9600 (default). The connection speed is configured on
%               the pump (see users manual).
%
% Class member functions:
%       getStatus() - get the status of the pump. Will be stopped, forward,
%           reverse, stalled, or unknown.
%       setRate(rate, units) - set the rate and units for the pumping.
%       setDiameter(d) - Set the diameter of the syringe (mm).
%       setTargetVolume(v) - Set target volume (mL).
%       run(dir) - Run the pump forward ('f') or reverse ('r').
%       clearTargetVolume() - Reset target volume to zero.
%       resetPumpedVolume() - Reset pumped volume to zero.
%       getDiameter() - Get the set pump diameter (mm).
%       getRate() - Get the set rate for pumping (mL).
%       getPumpedVolume() - Get the pumped volume (mL).
%       getTargetVolume() - Get the set target volume (mL).

classdef SyringePump
   properties
      s % The serial connection
   end
   properties (Hidden)
        cleanup
   end
   methods
    function obj = SyringePump(comPort, baudRate)
        
        % Set parameters to default values if nothing received
        if  nargin < 2
            baudRate = 9600;
        end
        if  nargin < 1
            comPort = "COM1";
        end
        % Start the serial connection
        serial_options = {...
            'BaudRate',baudRate,...
            'DataBits',8,...
            'Parity','none',...
            'StopBits',2,...
            'FlowControl','none',...
            'Terminator',[]...
            };
        obj.s = serial(comPort);
        obj.cleanup = onCleanup(@()delete(obj));  % Callback to close
        set(obj.s,serial_options{:});
        fopen(obj.s);
        try
            obj.getStatus();
        catch
            error('Unable to establish connection with pump.')
        end
        obj.clearTargetVolume();
    end
    
    %======================================================================
    % Get the status of the device. 
    %
    % Return: String with one of the following values.
    %  - "stopped"
    %  - "forward"
    %  - "reverse"
    %  - "stalled"
    %======================================================================
    function status = getStatus(obj)
        [~, status] = obj.runQuery('');
    end
    
    %======================================================================
    % Set the rate of the pump. 
    %
    % rate: Numeric value specifying the rate.
    % units: Units for the rate.
    %  - "ul/m" - microliter per minute
    %  - "ml/hr" - milliliter per hour
    %  - "ul/hr" - microliter per hour
    %  - "ml/m" - milliliter per minute (default)
    % Returns: true if success, false if fail (value out of range)
    %======================================================================
    function success = setRate(obj, rate, units)
        success = false;
        if exist('rate', 'var') && rate > 0
            if exist('units', 'var')
                switch units
                   case "ul/m"
                      command = "ULM";
                   case "ml/hr"
                      command = "MLM";
                   case "ul/hr"
                      command = "ULH";
                    otherwise %"ml/m"
                      command = "MLM";
                end
            else
                command = "MLM";
            end

            % Truncate to 5 sig digits.
            rate = string(rate);
            rate = rate(1:min(end,5));

            success = obj.runQuery(command+rate);
        end
    end
    
    %======================================================================
    % Set the diameter of the syringe in mm. Used for rate and volume
    % calculations.
    %
    % d: Diameter of the syringe.
    % Returns: true if success, false if fail (value out of range)
    %======================================================================
    function success = setDiameter(obj, d)
        success = false;
        if exist('d', 'var') && d > 0
            % Truncate to 5 sig digits.
            d = string(d);
            d = d(1:min(end,5));

            success = obj.runQuery("MMD "+d);
        end
    end
    
    %======================================================================
    % Set the target infusion volume. Units are in ml.
    %
    % v: Volume to infuse.
    % Returns: true if success, false if fail (value out of range)
    %======================================================================
    function success = setTargetVolume(obj, v)
        success = false;
        if exist('v', 'var') && v > 0
            % Truncate to 5 sig digits.
            v = string(v);
            v = v(1:min(end,5));

            success = obj.runQuery("MLT "+v);
        end
    end
    
    %======================================================================
    % Run the pump forward.
    %
    % dir: direction to run. f or r. May be ommited.
    %======================================================================
    function run(obj, dir)
        if exist('dir', 'var') && dir == 'r'
            command = "REV";
        else
            command = "RUN";
        end
        
        obj.runQuery(command);
    end
    
    %======================================================================
    % Stop the pump.
    %======================================================================
    function stop(obj)
        obj.runQuery("STP");
    end
    
    %======================================================================
    % Clear target volume to zero, dispense disabled.
    %======================================================================
    function clearTargetVolume(obj)
        obj.runQuery("CLT");
    end 
    
    %======================================================================
    % Reset the total volume pumped to zero.
    %======================================================================
    function resetPumpedVolume(obj)
        obj.runQuery("CLV");
    end
    
    %======================================================================
    % Get the diameter that is set for the pump in mm.
    % 
    % Returns: the set diameter.
    %======================================================================
    function d = getDiameter(obj)
        d = obj.runQuery("DIA");
    end
    
    %======================================================================
    % Get the rate value in the current range units.
    % 
    % Returns: the set rate.
    %======================================================================
    function rate = getRate(obj)
        rate = obj.runQuery("RAT");
    end
    
    %======================================================================
    % Get the current pumped volume in ml.
    % 
    % Returns: the pumped volume.
    %======================================================================
    function v = getPumpedVolume(obj)
        v = obj.runQuery("VOL");
    end
    
    %======================================================================
    % Get the current target volume in ml.
    % 
    % Returns: the target volume.
    %======================================================================
    function v = getTargetVolume(obj)
        v = obj.runQuery("TAR");
    end
   end
   methods (Access = private)
    function delete(obj)
        if obj.s ~= -1
            fclose(obj.s);
        end
        delete(obj.s);
    end
    
    function [response, status] = runQuery(obj, query)
        flushinput(obj.s); %TODO: probably don't need this.
        
        %Send the query
        fprintf(obj.s,sprintf('%s\r',query));
        
        % Define max wait times in s
        BYTE_WAIT_TIME = (12 / obj.s.BaudRate) * 4; % x8 to be safe...
        MAX_INITIAL_WAIT_TIME = 1;
        MAX_READ_WAIT_TIME = 0.5;
        
        % Wait to receive value
        i = 0;
        while obj.s.BytesAvailable == 0
            pause(BYTE_WAIT_TIME);
            i = i + 1;
            if BYTE_WAIT_TIME*i > MAX_INITIAL_WAIT_TIME
                    error('Communication with pump timed out. No data received.')
            end
        end
        
        % Wait to receive all the data
        i = 0;
        validEndChars = [':' '<' '>' '*' '?'];
        data = fscanf(obj.s,'%c',obj.s.BytesAvailable);
        while ~any(validEndChars(:) == data(end))
            % Check for timeout
            if BYTE_WAIT_TIME*i > MAX_READ_WAIT_TIME
                    error('Transmission from pump timed out.')
            end
            pause(BYTE_WAIT_TIME);
            i = i + 1;
            
            % Read any new data if available
            if obj.s.BytesAvailable > 0
                data = [data fscanf(obj.s,'%c',obj.s.BytesAvailable)];
            end
        end
        
        % Split the data
        data = strsplit(data);
        
        % Parse the response value if we got one
        if length(data) == 3
            if strcmp(data{2}, 'OOR')
                response = false;
            else
                response = str2double(data{2});
            end
        else
            response = true;
        end
        
        % Get the status
        status = obj.parseStatus(data{end});
    end
    
    function status = parseStatus(obj, code)
        switch code
           case ":"
              status = "stopped";
           case ">"
              status = "forward";
           case "<"
              status = "reverse";
           case "*"
              status = "stalled";
           otherwise
              status = "unknown";
        end
    end
   end
end