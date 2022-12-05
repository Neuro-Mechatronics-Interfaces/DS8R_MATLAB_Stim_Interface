classdef DS8R_Stim_GUI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        DS8RInterfaceUIFigure           matlab.ui.Figure
        ConnecttofirstDAQdeviceseenLabel  matlab.ui.control.Label
        ConnectButton                   matlab.ui.control.Button
        SaveButton                      matlab.ui.control.Button
        LoadButton                      matlab.ui.control.Button
        STOPButton                      matlab.ui.control.Button
        STARTButton                     matlab.ui.control.Button
        OutputLamp                      matlab.ui.control.Lamp
        OutputLampLabel                 matlab.ui.control.Label
        LogEditField                    matlab.ui.control.TextArea
        TabGroup                        matlab.ui.container.TabGroup
        ShulgachBurstBuilderTab         matlab.ui.container.Tab
        WaveformParametersPanel         matlab.ui.container.Panel
        PulseWidthParam                 matlab.ui.control.Spinner
        Spinner2_2Label                 matlab.ui.control.Label
        AmplitudeParam                  matlab.ui.control.Spinner
        Spinner2Label                   matlab.ui.control.Label
        WaveformProfileRepeatDelaymsEditField  matlab.ui.control.NumericEditField
        WaveformProfileRepeatDelaymsEditFieldLabel  matlab.ui.control.Label
        WaveformProfileRepetitionsEditField  matlab.ui.control.NumericEditField
        WaveformProfileRepetitionsEditFieldLabel  matlab.ui.control.Label
        PreStimDelaymsEditField         matlab.ui.control.NumericEditField
        PreStimDelaymsEditFieldLabel    matlab.ui.control.Label
        NPulsesEditField                matlab.ui.control.NumericEditField
        NPulsesEditFieldLabel           matlab.ui.control.Label
        PostStimDelaymsEditField        matlab.ui.control.NumericEditField
        PostStimDelaymsEditFieldLabel   matlab.ui.control.Label
        AmplitudeLimitmAEditField       matlab.ui.control.NumericEditField
        AmplitudeLimitmAEditFieldLabel  matlab.ui.control.Label
        StimChannelDropDown             matlab.ui.control.DropDown
        StimChannelDropDownLabel        matlab.ui.control.Label
        WaveformProfilePanel            matlab.ui.container.Panel
        WaveformTable                   matlab.ui.control.Table
        DELETEButton                    matlab.ui.control.Button
        ADDWAVEFORMButton               matlab.ui.control.Button
        ConfigurationSettingsTab        matlab.ui.container.Tab
        VirtualCheckBox                 matlab.ui.control.CheckBox
        DisabledButton_3                matlab.ui.control.StateButton
        DisabledButton_2                matlab.ui.control.StateButton
        DisabledButton_1                matlab.ui.control.StateButton
        EventTriggerPanel               matlab.ui.container.Panel
        TriggerChannelDropDown          matlab.ui.control.DropDown
        TriggerChannelDropDownLabel     matlab.ui.control.Label
        TriggerVoltageDropDown          matlab.ui.control.DropDown
        TriggerVoltageDropDownLabel     matlab.ui.control.Label
        SignalInputMonitoringPanel      matlab.ui.container.Panel
        SaveScanCheckBox                matlab.ui.control.CheckBox
        AnalogInputRecordingChannelDropDown  matlab.ui.control.DropDown
        AnalogInputRecordingChannelDropDownLabel  matlab.ui.control.Label
        EnableInputreadingCheckBox      matlab.ui.control.CheckBox
        StimulatorChannel2Panel         matlab.ui.container.Panel
        OutputChan_2                    matlab.ui.control.DropDown
        StimulatorOutputChannelDropDown_2Label  matlab.ui.control.Label
        TrigChan_2                      matlab.ui.control.DropDown
        StimulatorEnableChannelDropDown_2Label  matlab.ui.control.Label
        StimulatorChannel1Panel         matlab.ui.container.Panel
        OutputChan_1                    matlab.ui.control.DropDown
        StimulatorChannelLabel          matlab.ui.control.Label
        TrigChan_1                      matlab.ui.control.DropDown
        StimulatorEnableChannelDropDownLabel  matlab.ui.control.Label
        SampleRateEditField             matlab.ui.control.NumericEditField
        SampleRateEditFieldLabel        matlab.ui.control.Label
        DAQTypeDropDown                 matlab.ui.control.DropDown
        DAQTypeDropDownLabel            matlab.ui.control.Label
        PulseSignalPaddingmsEditField   matlab.ui.control.NumericEditField
        PulseSignalPaddingmsEditFieldLabel  matlab.ui.control.Label
        DescriptionEditField            matlab.ui.control.EditField
        DescriptionEditFieldLabel       matlab.ui.control.Label
        Panel                           matlab.ui.container.Panel
        Label                           matlab.ui.control.Label
        ConnectedDeviceEditField        matlab.ui.control.EditField
        ConnectedDeviceEditFieldLabel   matlab.ui.control.Label
        WaveformAxes                    matlab.ui.control.UIAxes
    end


    properties (Hidden, Access=public)
        Parent
    end

    properties (Access = private)
        HFVector % vector to hold aimplitude output vector to send to DAQ
        SampleRate %sample rate
        trig_signal_t % time variable to hold timing vector for plotting
        trig_signal % vector for visualized analog output
        stim_signal % vector for actual analog signal to be sent to DS8R
        version % placeholder for version information and debugging notes
        pulsewidth
        stimamplitude
        frequency
        start_t = 0;
        end_t = 1;
        dev % DAQ device handle placeholder
        debug = true; % High level debugging toggle, set to true when testing
        prev_amp = 0;
        prev_post_stim_delay = 1;
        pad_1ms % placeholder for calculating the 1ms in elements for padding
        extra_pad = 1; % scalar gain in seconds of extra signal writing for DS8R in case more than 1ms is needed
        record_chan = false; % placeholder for enable/disable analog input recording option, default false
        scan_data % placeholder for analog input data
        current_chan = 1;
        ChanData; % Main struct handling all waveform data for each stim channel
        line_color = {[0.07 0.62 1], [1 0 0], [0.39 0.83 0.07], [0.93 0.69 0.13]};
    end

    events
        Start_Stim
        Stop_Stim
    end

    methods (Access = private)

        function update_gui(app)
            %[app.trig_signal, app.stim_signal] = assemble_full_waveform(app);
            [app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal, app.ChanData.(['stim_chan_',num2str(app.current_chan)]).stim_signal] = update_burst_train(app);
            update_figure(app);
        end

        function update_figure(app)
            % update the figure with the waveform vector

            % To fit the square waveform in the figure we need to add zeros
            % to the start and end
            stim_chans = app.StimChannelDropDown.Items;
            first_plot = true;
            min_lim = 0;
            max_lim = 0;
            for i=1:length(stim_chans)
                chan = str2double(stim_chans{i});
                pad_t_start_idx = -app.pad_1ms; % add -1ms pre-event
                pad_t_end_idx = length(app.ChanData.(['stim_chan_',num2str(chan)]).trig_signal) + app.pad_1ms; % 1ms post waveform
                padded_x = [repelem(0, app.pad_1ms), app.ChanData.(['stim_chan_',num2str(chan)]).trig_signal, repelem(0, app.pad_1ms)];
                padded_x_t = linspace(pad_t_start_idx/app.pad_1ms, pad_t_end_idx/app.pad_1ms, length(padded_x));
                plot(app.WaveformAxes, padded_x_t, padded_x, 'LineWidth', 1, 'Color', app.line_color{chan});
                if first_plot == true
                    hold(app.WaveformAxes,'on');
                    first_plot = false;
                end
                if max(padded_x) > max_lim
                    max_lim = max(padded_x);
                end
                if min(padded_x) < min_lim
                    min_lim = min(padded_x);
                end
            end
            hold(app.WaveformAxes,'off');

            if size(app.WaveformTable.Data, 1) ~= 0
                set(app.WaveformAxes, 'ylim', [min_lim - 0.1, max_lim + 0.1*max_lim]);
            end

        end

        function data_x = build_waveform(app, amp, pw, rep, wait)
            % Build square waveforms, one for visualizer to use for trigger, one for actual signal to be sent to DS8R
            data_x = [linspace(amp, amp, floor(pw*app.pad_1ms)), linspace(0, 0, floor(wait*app.pad_1ms))];
            %new_x = repmat(data_x, 1, rep);
        end

        function add_to_waveform_list(app)

            % add a new square waveform to the list
            amp = app.AmplitudeParam.Value;
            pw = app.PulseWidthParam.Value;
            rep = app.NPulsesEditField.Value;
            wait = app.PostStimDelaymsEditField.Value;
            app.WaveformTable.Data = [app.WaveformTable.Data; {amp, pw, rep, wait}];

            % Update analog output vector to accomodate new full-length waveform
            [app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal, app.ChanData.(['stim_chan_',num2str(app.current_chan)]).stim_signal] = assemble_full_waveform(app);

            % For graphing the waveform, check that the timescale also
            % matches the stim output vector
            app.end_t = floor(length(app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal)/app.SampleRate);
            app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal_t = linspace(app.start_t, app.end_t, app.end_t*app.SampleRate);

        end

        function remove_from_waveform_list(app)
            % Remove the last item in the waveform list
            temp = app.WaveformTable.Data;
            if ~isempty(temp)
                temp(end,:) = [];
                app.WaveformTable.Data = temp;

                % Update analog output vector to accomodate new waveform
                [app.trig_signal, app.stim_signal] = assemble_full_waveform(app);
                app.end_t = floor(length(app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal)/app.SampleRate);
                app.trig_signal_t = linspace(app.start_t, app.end_t, app.end_t*app.SampleRate);
            end
        end

        function [full_x, full_y] = assemble_full_waveform(app)
            % Get each table element and create the vector of waveforms
            full_x = [];
            full_y = [];
            [n_burst, ~] = size(app.WaveformTable.Data);
            if n_burst ~= 0
                for i=1:n_burst
                    [amp, pw, rep, wait_ms] = app.WaveformTable.Data{i,:};
                    temp_x = build_waveform(app, amp, pw, rep, wait_ms);
                    for r=1:rep
                        % Adjust waveform if amplitudes are different with interpulse delay less than 1ms
                        if app.prev_amp ~= amp
                            if app.prev_post_stim_delay < 1
                                zero_idx = diff(full_x); % Getting the index of the last falling edge of the stim waveform this way
                                full_x(zero_idx(end):zero_idx(end)+app.pad_1ms) = 0; % pad 1ms with zeros
                            end
                        end
                        full_x = [full_x, temp_x];
                        app.prev_amp = amp;
                        app.prev_post_stim_delay = wait_ms;

                        end_idx = length(full_y); % get end index of stim signal, which is start of new stim signal
                        full_y = [full_y, temp_x];
                        if end_idx~=0
                            if end_idx <= (2*app.pad_1ms) || length(full_y) <= (app.extra_pad*app.pad_1ms)
                                %if length(full_y) <= (2*app.pad_1ms)
                                full_y(1:end) = amp; % padd 2 ms
                            else
                                full_y(end_idx-(app.extra_pad*app.pad_1ms)+1:end_idx) = amp; % padd 2 ms
                            end
                        end
                    end

                end
            end
        end

        function [x_train, y_train] = update_burst_train(app)
            % Takes the entire burst list and increases the vector by the
            % number of repeats
            burst_rep = app.WaveformProfileRepetitionsEditField.Value;
            burst_delay = app.WaveformProfileRepeatDelaymsEditField.Value;
            [temp_x, temp_y] = assemble_full_waveform(app);
            %app.end_t = floor(1000*length(app.trig_signal)/app.SampleRate);
            %app.trig_signal_t = linspace(app.start_t, app.end_t, app.end_t*app.SampleRate);
            x_train = [];
            y_train = [];
            [n_burst, ~] = size(app.WaveformTable.Data);
            if n_burst == 0
                return;
            end
            if burst_rep > 1
                if burst_delay < 1000*(length(temp_x))/app.SampleRate
                    x_train = temp_x;
                    y_train = temp_y;
                    logger(app,"Error - burst train delay is shorter than burst length");
                else
                    for b=1:burst_rep
                        % Set the stim vector at the beginning of the adjusted_x vector so the burst delay is syncronized with the first stim pulse
                        adjusted_x = linspace(0, 0, burst_delay*app.SampleRate/1000);
                        adjusted_x(1:length(temp_x)) = temp_x;
                        x_train = [x_train, adjusted_x];

                        adjusted_y = linspace(0, 0, burst_delay*app.SampleRate/1000);
                        adjusted_y(1:length(temp_y)) = temp_y;
                        end_idx = length(y_train); % get end index of stim signal, which is start of new stim signal
                        y_train = [y_train, adjusted_y];
                        if end_idx~=0
                            if end_idx <= (2*app.pad_1ms) || length(y_train) <= (2*app.pad_1ms)
                                y_train(1:end) = temp_y(1); % padd 2 ms
                            else
                                y_train(end_idx-(2*app.pad_1ms)+1:end_idx) = temp_y(1); % padd 2 ms
                            end
                        end

                    end
                end
            else
                x_train = temp_x;
                y_train = temp_y;
            end

            % final time
            app.end_t = floor(1000*length(x_train)/app.SampleRate);
            app.ChanData.(['stim_chan_',num2str(app.current_chan)]).trig_signal_t = linspace(app.start_t, app.end_t, app.end_t*app.SampleRate);

        end

        function result = connect_to_device(app)
            if app.VirtualCheckBox.Value == true
                result = 1;
            else
                try
                    daqreset;
                    logger(app, sprintf("Searching for %s DAQ device...", app.DAQTypeDropDown.Value));
                    drawnow;
                    devices = daqlist(app.DAQTypeDropDown.Value);
                    if isempty(devices)
                        result = -1;
                        logger(app, 'Error - No DAQ devices found');
                    else
                        warning('off', 'daq:Session:onDemandOnlyChannelsAdded');
                        dq = daq(app.DAQTypeDropDown.Value);
                        app.dev = dq(1);
                        devID = devices.DeviceID(1);
                        app.ConnectedDeviceEditField.Value = devID;
                        app.DescriptionEditField.Value = devices.Description(1);
                        app.dev.Rate = app.SampleRateEditField.Value;

                        % device configuration settings
                        trig_chan = app.TriggerChannelDropDown.Value;
                        rec_chan = app.AnalogInputRecordingChannelDropDown.Value;
                        stim_enable_chan = {};
                        stim_chan = {};
                        for i=1:length(str2double(app.StimChannelDropDown.Items))
                            stim_enable_chan{i} = app.(['TrigChan_',num2str(i)]).Value;
                            stim_chan{i} = app.(['OutputChan_',num2str(i)]).Value;
                        end
                        switch devID
                            case "Dev1"  % NI-DAQ
                                addoutput(app.dev,devID,stim_chan,'Voltage'); % for stimulation amplitude control
                                addoutput(app.dev,devID,stim_enable_chan,'Digital'); % for triggering stimulator
                                addoutput(app.dev,devID,trig_chan,'Voltage'); % for stimulation amplitude control
                                if app.record_chan == true
                                    addinput(app.dev,devID,rec_chan, 'Voltage'); % for recording input signal
                                end
                            case "AD2_0" % DIGILENT ANALOG DISCOVERY 2
                                addoutput(app.dev,devID,stim_chan,'Voltage'); % for stimulation amplitude control
                                %                             addoutput(app.dev,devID,stim_enable_chan,'Digital'); % for triggering stimulator
                                addoutput(app.dev,devID,trig_chan,'Voltage'); % for stimulation amplitude control
                                if app.record_chan == true
                                    addinput(app.dev,devID,rec_chan, 'Voltage'); % for recording input signal
                                end
                            otherwise
                                error("Unrecognized DeviceID for DAQ: %s", devID);
                        end

                        warning('on', 'daq:Session:onDemandOnlyChannelsAdded');
                        result = 1;
                    end
                catch ME
                    result = -2;
                    logger(app, 'Error - Failed connecting to DAQ device');
                    assignin("base", "ME", ME);
                    app.OutputLamp.Color = [0.8 0.2 0.2];
                end
            end
        end


        function logger(app, msg)
            % Update the front indicator with the string message passed
            % into msg (assumed string ot char vector input)
            app.LogEditField.Value = msg;
        end

        function varargout = enable_stim_channel(app, chan, val)
            % Handle sublevel initialization of output channel after enabling/disabling
            app.ChanData.(['stim_chan_',num2str(chan)]).enabled = val;
            if val == true
                app.(['DisabledButton_',num2str(chan)]).Value = true;
                app.(['DisabledButton_',num2str(chan)]).Text = 'Enabled';
                app.(['DisabledButton_',num2str(chan)]).BackgroundColor = [0.4 0.8 0.07];
                add_stim_channel_to_waveform(app, chan);
            else
                app.(['DisabledButton_',num2str(chan)]).Value = false;
                app.(['DisabledButton_',num2str(chan)]).Text = 'Disabled';
                app.(['DisabledButton_',num2str(chan)]).BackgroundColor = [0.96 0.96 0.96];
                remove_stim_channel_from_waveform(app, chan);
            end

        end

        function add_stim_channel_to_waveform(app, chan)
            % Make sure desired stim channel is in the waveform profile table
            app.ChanData.(['stim_chan_',num2str(chan)]).TableData = {};
            app.ChanData.(['stim_chan_',num2str(chan)]).enabled = true;
            app.ChanData.(['stim_chan_',num2str(chan)]).current_vector = [];
            app.ChanData.(['stim_chan_',num2str(chan)]).trigger_vector = [];

            % Restore GUI parameter values
            app.ChanData.(['stim_chan_',num2str(chan)]).AmplitudeParam = app.AmplitudeParam.Value;
            app.ChanData.(['stim_chan_',num2str(chan)]).PulseWidthParam = app.PulseWidthParam.Value;
            app.ChanData.(['stim_chan_',num2str(chan)]).WaveformProfileRepetitions = app.WaveformProfileRepetitionsEditField.Value;
            app.ChanData.(['stim_chan_',num2str(chan)]).WaveformProfileRepeatDelayms = app.WaveformProfileRepeatDelaymsEditField.Value;

            % Add new stim channel option for toggle menu
            app.StimChannelDropDown.Items = sort([num2str(chan), app.StimChannelDropDown.Items]);
            msg = ['Added new stimulation channel: ',num2str(chan)];
            logger(app, msg);
        end

        function remove_stim_channel_from_waveform(app, chan)
            temp = app.StimChannelDropDown.Items;
            temp(find(strcmp(temp, num2str(chan)))) = [];
            app.StimChannelDropDown.Items = temp;
            app.ChanData.(['stim_chan_',num2str(chan)]) = [];
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Setting up default values, draw a line of 0V for 1.2 sec on
            % graph
            %if isempty(app.dev)
            app.start_t = 0;
            app.end_t = 1;
            app.SampleRate = app.SampleRateEditField.Value;
            app.pad_1ms = round(app.SampleRateEditField.Value/1000);
            app.record_chan = app.EnableInputreadingCheckBox.Value;

            app.LogEditField.Value = "Ready to connect to DAQ device. Press the Connect button.";
            app.trig_signal_t = linspace(app.start_t,app.end_t,1.2*app.SampleRate);
            app.trig_signal = linspace(0,0,1.2*app.SampleRate);

            % Start with only the first stimulator channel enabled
            enable_stim_channel(app, 1, true);
            add_to_waveform_list(app);
            update_gui(app);

            % Reset DAQ device connections
            daqreset;

            app.version = 'October 30th, 2022 (v3.1)';

        end

        % Button pushed function: ADDWAVEFORMButton
        function ADDWAVEFORMButtonPushed(app, event)
            add_to_waveform_list(app);
            update_gui(app);

        end

        % Button pushed function: DELETEButton
        function DELETEButtonPushed(app, event)
            remove_from_waveform_list(app);
            update_gui(app);

        end

        % Value changed function: WaveformProfileRepetitionsEditField
        function WaveformProfileRepetitionsEditFieldValueChanged(app, event)
            update_gui(app);
        end

        % Value changed function: WaveformProfileRepeatDelaymsEditField
        function WaveformProfileRepeatDelaymsEditFieldValueChanged(app, event)
            update_gui(app);
        end

        % Value changed function: SampleRateEditField
        function SampleRateEditFieldValueChanged(app, event)
            app.SampleRate = app.SampleRateEditField.Value;
            update_gui(app);
            if ~isempty(app.dev)
                app.dev.Rate = app.SampleRate;
            end

        end

        % Button pushed function: ConnectButton
        function ConnectButtonPushed(app, event)
            if strcmpi(app.ConnectButton.Text, 'Connect')
                app.ConnectButton.Text = 'Connecting...';
                app.ConnectButton.Enable = 'off';
                drawnow;
                result = app.connect_to_device();
                if result > 0
                    logger(app, 'DAQ successfully connected!');
                    drawnow;
                    app.ConnectButton.Text = 'Disconnect';
                    app.ConnectButton.BackgroundColor = [0.65, 0.65, 0.65];
                    app.OutputLamp.Color = [0.1 0.9 0.1];
                else
                    switch result
                        case -1
                            % Do nothing
                        case -2
                            % Do nothing
                        otherwise
                            logger(app, 'Warning - Problem connecting to DAQ');
                    end
                end
                app.ConnectButton.Enable = 'on';
                app.STARTButton.Enable = 'on';
                app.STOPButton.Enable = 'on';
            elseif strcmpi(app.ConnectButton.Text, 'Disconnect')
                daqreset
                logger(app, 'DAQ disconnected');
                app.ConnectButton.Text = 'Connect';
                app.ConnectButton.BackgroundColor = [0.95, 0.95, 0.95];
                app.OutputLamp.Color = [0.65 0.65 0.65];
                app.dev = [];
                app.STARTButton.Enable = 'off';
                app.STOPButton.Enable = 'off';
            end

        end

        % Button pushed function: STARTButton
        function STARTButtonPushed(app, event)

            % Build stim vectors
            stim_chans = str2double(app.StimChannelDropDown.Items);
            TrigData = {};
            StimData = {};
            for i=1:length(stim_chans)
                pad_term = repelem(0, app.extra_pad*app.pad_1ms);
                trigVector = [pad_term, app.ChanData.(['stim_chan_',num2str(stim_chans(i))]).trig_signal, 0]'; % generate trigger signal
                trigVector(trigVector>1) = 1; % Double check that the highest value in vector is never greater than 1
                TrigData{i} = trigVector;

                pad_term = repelem(app.ChanData.(['stim_chan_',num2str(stim_chans(i))]).stim_signal(1), app.extra_pad*app.pad_1ms);
                stimVector = (10/app.AmplitudeLimitmAEditField.Value)*[pad_term, app.ChanData.(['stim_chan_',num2str(stim_chans(i))]).stim_signal, 0]'; % generate analog stim signal, convert to voltage
                StimData{i} = stimVector;
            end

            [StimData, tf] = padcat(StimData{:});
            StimData(~tf) = 0;

            [TrigData, tf] = padcat(TrigData{:});
            TrigData(~tf) = 0;

            % If the start event trigger is enabled then this channel is added
            if app.DisabledButton_3.Value == true
                hardwareTrigVector = ones(size(TrigData),1);
                hardwareTrigVector(app.pad_1ms:end) = str2double(app.TriggerVoltageDropDown.Value(1:end-2));
            end

            % Send stim vector waveform to the daq device
            switch app.DAQTypeDropDown.Value
                case "ni"
                    toLoad = [StimData, TrigData];
                    %toLoad = [stimVector trigVector hardwareTrigVector];
                case "digilent"
                    toLoad = [stimVector hardwareTrigVector];
                otherwise
                    error("Unhandled vendor: %s", app.DAQTypeDropDown.Value);
            end

            logger(app, "Begin Stim...");
            app.STARTButton.Enable = 'off';
            app.STARTButton.Text = "RUNNING...";
            app.OutputLamp.Color = [1.0, 1.0, 0.0];
            if ~isempty(app.dev)
                if app.record_chan == true
                    app.scan_data = readwrite(app.dev,  toLoad);
                else
                    preload(app.dev, toLoad) % stimulator output, enable signal, sync trigger.
                    evt = StimEventData(app.WaveformTable.Data);
                    notify(app,'Start_Stim', evt);

                    pause(0.5); % Give it a sec to start

                    %                     StartTime = fix(clock) %#ok<NASGU,NOPRT>
                    %start(app.dev,'RepeatOutput')
                    tic;
                    start(app.dev)
                    pause(app.trig_signal_t(end)/1000)
                    stop(app.dev)
                    toc;
                    notify(app, 'Stop_Stim');
                end

            else
                logger(app, 'DAQ not connected');
            end
            logger(app, "Stimulation complete!");
            app.OutputLamp.Color = [0.1, 0.9, 0.1];
            app.STARTButton.Enable = 'on';
            app.STARTButton.Text = "START";

            if app.SaveScanCheckBox.Value == true
                filter = {'*.txt';'*.csv';'*.mat'};
                [file, path] = uiputfile(filter, 'Scan Save');
                if ischar(file)
                    File = fullfile(path, file);
                    writetable(timetable2table(app.scan_data), File);
                else
                    disp('User aborted the dialog');
                end
            end
        end

        % Button pushed function: STOPButton
        function STOPButtonPushed(app, event)
            if ~isempty(app.dev)
                stop(app.dev);
            end
        end

        % Value changed function: NPulsesEditField
        function NPulsesEditFieldValueChanged(app, event)
            update_gui(app);

        end

        % Value changed function: PulseSignalPaddingmsEditField
        function PulseSignalPaddingmsEditFieldValueChanged(app, event)
            app.extra_pad = app.PulseSignalPaddingmsEditField.Value;
            update_gui(app);

        end

        % Value changed function: EnableInputreadingCheckBox
        function EnableInputreadingCheckBoxValueChanged(app, event)
            % Enables recording on specified analog input channel for debug,
            % this was the output from the DS8R or the NI hardware can be evaluated
            app.record_chan = app.EnableInputreadingCheckBox.Value;

            % Reconnect of already connected
            if ~isempty(app.dev)
                logger(app, 'Input enabled, restarting connection')
                result = app.connect_to_device();
                if result > 0
                    logger(app, 'DAQ successfully connected!');
                    app.ConnectButton.Text = 'Disconnect';
                    app.ConnectButton.BackgroundColor = [0.65, 0.65, 0.65];
                else
                    switch result
                        case -1
                            % Do nothing
                        case -2
                            % Do nothing
                        otherwise
                            logger(app, 'Warning - Problem connecting to DAQ');
                    end
                end
            end
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            % Saving parameters on GUI (TO-DO)
            logger(app, "Saving parameters - not ready");
        end

        % Value changed function: DAQTypeDropDown
        function DAQTypeDropDownValueChanged(app, event)
            value = app.DAQTypeDropDown.Value;
            switch value
                case "ni"
                    set(app.TrigChan_1, 'Items', ["Port0/Line0", "Port0/Line1"], 'Value', "Port0/Line0");
                    set(app.TrigChan_2, 'Items', ["Port0/Line0", "Port0/Line1"], 'Value', "Port0/Line1");
                case "digilent"
                    set(app.TrigChan_1, 'Items', ["dio00","dio01","dio02","dio03","dio04","dio05","dio06","dio07","dio08","dio09","dio10","dio11","dio12","dio13","dio14","dio15"], 'Value', "dio00");
                    set(app.TrigChan_2, 'Items', ["dio00","dio01","dio02","dio03","dio04","dio05","dio06","dio07","dio08","dio09","dio10","dio11","dio12","dio13","dio14","dio15"], 'Value', "dio01");
                otherwise
                    error("Unhandled DAQ vendor: %s", value);
            end
        end

        % Value changed function: DisabledButton_1
        function DisabledButton_1ValueChanged(app, event)
            value = app.DisabledButton_1.Value;
            if value == true
                enable_stim_channel(app, 1, true);
            else
                enable_stim_channel(app, 1, false);
            end
        end

        % Value changed function: StimChannelDropDown
        function StimChannelDropDownValueChanged(app, event)
            new_chan = str2double(app.StimChannelDropDown.Value);
            if app.current_chan ~= new_chan
                % Save waveform table data to stim chan
                app.ChanData.(['stim_chan_',num2str(app.current_chan)]).TableData = app.WaveformTable.Data;

                % Populate table data from previous stim chan session
                app.WaveformTable.Data = app.ChanData.(['stim_chan_',num2str(new_chan)]).TableData;

                % Restore GUI parameter values
                app.AmplitudeParam.Value = app.ChanData.(['stim_chan_',num2str(new_chan)]).AmplitudeParam;
                app.PulseWidthParam.Value = app.ChanData.(['stim_chan_',num2str(new_chan)]).PulseWidthParam;
                app.WaveformProfileRepetitionsEditField.Value = app.ChanData.(['stim_chan_',num2str(new_chan)]).WaveformProfileRepetitions;
                app.WaveformProfileRepeatDelaymsEditField.Value = app.ChanData.(['stim_chan_',num2str(new_chan)]).WaveformProfileRepeatDelayms;

                app.current_chan = new_chan;
            end
        end

        % Value changed function: DisabledButton_2
        function DisabledButton_2ValueChanged(app, event)
            value = app.DisabledButton_2.Value;
            if value == true
                enable_stim_channel(app, 2, true);
            else
                enable_stim_channel(app, 2, false);
            end
        end

        % Value changed function: VirtualCheckBox
        function VirtualCheckBoxValueChanged(app, event)
            value = app.VirtualCheckBox.Value;
            %if value == true
            %    %
            %end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create DS8RInterfaceUIFigure and hide until all components are created
            app.DS8RInterfaceUIFigure = uifigure('Visible', 'off');
            app.DS8RInterfaceUIFigure.Color = [1 1 1];
            app.DS8RInterfaceUIFigure.Position = [100 100 1239 665];
            app.DS8RInterfaceUIFigure.Name = 'DS8R Interface';
            app.DS8RInterfaceUIFigure.Icon = 'outline_flash_on_black_24dp.png';

            % Create WaveformAxes
            app.WaveformAxes = uiaxes(app.DS8RInterfaceUIFigure);
            title(app.WaveformAxes, 'Display Pulse Waveform Train')
            xlabel(app.WaveformAxes, 'Time (ms)')
            ylabel(app.WaveformAxes, 'Amplitude (mA)')
            zlabel(app.WaveformAxes, 'Z')
            app.WaveformAxes.FontSize = 16;
            app.WaveformAxes.Position = [700 190 527 413];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.DS8RInterfaceUIFigure);
            app.TabGroup.Position = [12 16 671 599];

            % Create ShulgachBurstBuilderTab
            app.ShulgachBurstBuilderTab = uitab(app.TabGroup);
            app.ShulgachBurstBuilderTab.Title = 'Shulgach Burst Builder';

            % Create ADDWAVEFORMButton
            app.ADDWAVEFORMButton = uibutton(app.ShulgachBurstBuilderTab, 'push');
            app.ADDWAVEFORMButton.ButtonPushedFcn = createCallbackFcn(app, @ADDWAVEFORMButtonPushed, true);
            app.ADDWAVEFORMButton.BackgroundColor = [0.902 0.902 0.902];
            app.ADDWAVEFORMButton.FontSize = 18;
            app.ADDWAVEFORMButton.Position = [145 275 210 35];
            app.ADDWAVEFORMButton.Text = 'ADD WAVEFORM';

            % Create DELETEButton
            app.DELETEButton = uibutton(app.ShulgachBurstBuilderTab, 'push');
            app.DELETEButton.ButtonPushedFcn = createCallbackFcn(app, @DELETEButtonPushed, true);
            app.DELETEButton.BackgroundColor = [0.9804 0.6549 0.6549];
            app.DELETEButton.FontSize = 18;
            app.DELETEButton.Position = [403 280 209 35];
            app.DELETEButton.Text = 'DELETE';

            % Create WaveformProfilePanel
            app.WaveformProfilePanel = uipanel(app.ShulgachBurstBuilderTab);
            app.WaveformProfilePanel.TitlePosition = 'centertop';
            app.WaveformProfilePanel.Title = 'Waveform Profile';
            app.WaveformProfilePanel.FontWeight = 'bold';
            app.WaveformProfilePanel.FontSize = 18;
            app.WaveformProfilePanel.Position = [57 28 565 227];

            % Create WaveformTable
            app.WaveformTable = uitable(app.WaveformProfilePanel);
            app.WaveformTable.ColumnName = {'Amplitude (mA)'; 'Pulse Width (ms)'; 'N Pulses'; 'Post-Stim Delay'};
            app.WaveformTable.RowName = {};
            app.WaveformTable.Position = [7 2 547 196];

            % Create StimChannelDropDownLabel
            app.StimChannelDropDownLabel = uilabel(app.ShulgachBurstBuilderTab);
            app.StimChannelDropDownLabel.HorizontalAlignment = 'right';
            app.StimChannelDropDownLabel.Position = [20 288 78 22];
            app.StimChannelDropDownLabel.Text = 'Stim Channel';

            % Create StimChannelDropDown
            app.StimChannelDropDown = uidropdown(app.ShulgachBurstBuilderTab);
            app.StimChannelDropDown.Items = {};
            app.StimChannelDropDown.ValueChangedFcn = createCallbackFcn(app, @StimChannelDropDownValueChanged, true);
            app.StimChannelDropDown.Position = [25 264 43 22];
            app.StimChannelDropDown.Value = {};

            % Create WaveformParametersPanel
            app.WaveformParametersPanel = uipanel(app.ShulgachBurstBuilderTab);
            app.WaveformParametersPanel.Title = 'Waveform Parameters';
            app.WaveformParametersPanel.FontWeight = 'bold';
            app.WaveformParametersPanel.FontSize = 14;
            app.WaveformParametersPanel.Position = [12 337 640 221];

            % Create AmplitudeLimitmAEditFieldLabel
            app.AmplitudeLimitmAEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.AmplitudeLimitmAEditFieldLabel.HorizontalAlignment = 'right';
            app.AmplitudeLimitmAEditFieldLabel.FontSize = 16;
            app.AmplitudeLimitmAEditFieldLabel.Position = [79 169 154 22];
            app.AmplitudeLimitmAEditFieldLabel.Text = 'Amplitude Limit (mA)';

            % Create AmplitudeLimitmAEditField
            app.AmplitudeLimitmAEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.AmplitudeLimitmAEditField.FontSize = 16;
            app.AmplitudeLimitmAEditField.Position = [253 169 60 22];
            app.AmplitudeLimitmAEditField.Value = 1000;

            % Create PostStimDelaymsEditFieldLabel
            app.PostStimDelaymsEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.PostStimDelaymsEditFieldLabel.HorizontalAlignment = 'right';
            app.PostStimDelaymsEditFieldLabel.FontSize = 16;
            app.PostStimDelaymsEditFieldLabel.Position = [384 131 157 22];
            app.PostStimDelaymsEditFieldLabel.Text = 'Post-Stim Delay (ms)';

            % Create PostStimDelaymsEditField
            app.PostStimDelaymsEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.PostStimDelaymsEditField.ValueDisplayFormat = '%11.2f';
            app.PostStimDelaymsEditField.FontSize = 16;
            app.PostStimDelaymsEditField.Position = [551 131 47 22];
            app.PostStimDelaymsEditField.Value = 1;

            % Create NPulsesEditFieldLabel
            app.NPulsesEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.NPulsesEditFieldLabel.HorizontalAlignment = 'right';
            app.NPulsesEditFieldLabel.FontSize = 16;
            app.NPulsesEditFieldLabel.Position = [471 96 70 22];
            app.NPulsesEditFieldLabel.Text = 'N Pulses';

            % Create NPulsesEditField
            app.NPulsesEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.NPulsesEditField.ValueDisplayFormat = '%11d';
            app.NPulsesEditField.ValueChangedFcn = createCallbackFcn(app, @NPulsesEditFieldValueChanged, true);
            app.NPulsesEditField.FontSize = 16;
            app.NPulsesEditField.Position = [551 96 48 22];
            app.NPulsesEditField.Value = 1;

            % Create PreStimDelaymsEditFieldLabel
            app.PreStimDelaymsEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.PreStimDelaymsEditFieldLabel.HorizontalAlignment = 'right';
            app.PreStimDelaymsEditFieldLabel.FontSize = 16;
            app.PreStimDelaymsEditFieldLabel.Position = [391 169 150 22];
            app.PreStimDelaymsEditFieldLabel.Text = 'Pre-Stim Delay (ms)';

            % Create PreStimDelaymsEditField
            app.PreStimDelaymsEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.PreStimDelaymsEditField.ValueDisplayFormat = '%11.2f';
            app.PreStimDelaymsEditField.FontSize = 16;
            app.PreStimDelaymsEditField.Position = [551 169 48 22];

            % Create WaveformProfileRepetitionsEditFieldLabel
            app.WaveformProfileRepetitionsEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.WaveformProfileRepetitionsEditFieldLabel.HorizontalAlignment = 'right';
            app.WaveformProfileRepetitionsEditFieldLabel.FontSize = 16;
            app.WaveformProfileRepetitionsEditFieldLabel.Position = [18 36 213 22];
            app.WaveformProfileRepetitionsEditFieldLabel.Text = 'Waveform Profile Repetitions';

            % Create WaveformProfileRepetitionsEditField
            app.WaveformProfileRepetitionsEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.WaveformProfileRepetitionsEditField.ValueChangedFcn = createCallbackFcn(app, @WaveformProfileRepetitionsEditFieldValueChanged, true);
            app.WaveformProfileRepetitionsEditField.FontSize = 16;
            app.WaveformProfileRepetitionsEditField.Position = [242 36 34 22];
            app.WaveformProfileRepetitionsEditField.Value = 5;

            % Create WaveformProfileRepeatDelaymsEditFieldLabel
            app.WaveformProfileRepeatDelaymsEditFieldLabel = uilabel(app.WaveformParametersPanel);
            app.WaveformProfileRepeatDelaymsEditFieldLabel.HorizontalAlignment = 'right';
            app.WaveformProfileRepeatDelaymsEditFieldLabel.FontSize = 16;
            app.WaveformProfileRepeatDelaymsEditFieldLabel.Position = [283 35 268 22];
            app.WaveformProfileRepeatDelaymsEditFieldLabel.Text = 'Waveform Profile Repeat Delay (ms)';

            % Create WaveformProfileRepeatDelaymsEditField
            app.WaveformProfileRepeatDelaymsEditField = uieditfield(app.WaveformParametersPanel, 'numeric');
            app.WaveformProfileRepeatDelaymsEditField.ValueChangedFcn = createCallbackFcn(app, @WaveformProfileRepeatDelaymsEditFieldValueChanged, true);
            app.WaveformProfileRepeatDelaymsEditField.FontSize = 16;
            app.WaveformProfileRepeatDelaymsEditField.Position = [565 35 56 22];
            app.WaveformProfileRepeatDelaymsEditField.Value = 1000;

            % Create Spinner2Label
            app.Spinner2Label = uilabel(app.WaveformParametersPanel);
            app.Spinner2Label.HorizontalAlignment = 'right';
            app.Spinner2Label.FontSize = 16;
            app.Spinner2Label.Position = [85 131 116 22];
            app.Spinner2Label.Text = 'Amplitude (mA)';

            % Create AmplitudeParam
            app.AmplitudeParam = uispinner(app.WaveformParametersPanel);
            app.AmplitudeParam.ValueDisplayFormat = '%11d';
            app.AmplitudeParam.FontSize = 16;
            app.AmplitudeParam.Position = [220 131 100 22];
            app.AmplitudeParam.Value = 20;

            % Create Spinner2_2Label
            app.Spinner2_2Label = uilabel(app.WaveformParametersPanel);
            app.Spinner2_2Label.HorizontalAlignment = 'right';
            app.Spinner2_2Label.FontSize = 16;
            app.Spinner2_2Label.Position = [77 96 127 22];
            app.Spinner2_2Label.Text = 'Pulse Width (ms)';

            % Create PulseWidthParam
            app.PulseWidthParam = uispinner(app.WaveformParametersPanel);
            app.PulseWidthParam.ValueDisplayFormat = '%11.2f';
            app.PulseWidthParam.FontSize = 16;
            app.PulseWidthParam.Position = [219 96 100 22];
            app.PulseWidthParam.Value = 1;

            % Create ConfigurationSettingsTab
            app.ConfigurationSettingsTab = uitab(app.TabGroup);
            app.ConfigurationSettingsTab.Title = 'Configuration Settings ';

            % Create ConnectedDeviceEditFieldLabel
            app.ConnectedDeviceEditFieldLabel = uilabel(app.ConfigurationSettingsTab);
            app.ConnectedDeviceEditFieldLabel.HorizontalAlignment = 'right';
            app.ConnectedDeviceEditFieldLabel.Position = [22 496 104 22];
            app.ConnectedDeviceEditFieldLabel.Text = 'Connected Device';

            % Create ConnectedDeviceEditField
            app.ConnectedDeviceEditField = uieditfield(app.ConfigurationSettingsTab, 'text');
            app.ConnectedDeviceEditField.Editable = 'off';
            app.ConnectedDeviceEditField.Position = [141 496 140 22];

            % Create Panel
            app.Panel = uipanel(app.ConfigurationSettingsTab);
            app.Panel.Position = [22 379 616 60];

            % Create Label
            app.Label = uilabel(app.Panel);
            app.Label.WordWrap = 'on';
            app.Label.Position = [8 -2 593 65];
            app.Label.Text = 'Caution: Digital IO channels may output 5V. Please check maximum voltage limits for receiving hardware';

            % Create DescriptionEditFieldLabel
            app.DescriptionEditFieldLabel = uilabel(app.ConfigurationSettingsTab);
            app.DescriptionEditFieldLabel.HorizontalAlignment = 'right';
            app.DescriptionEditFieldLabel.Position = [22 461 66 22];
            app.DescriptionEditFieldLabel.Text = 'Description';

            % Create DescriptionEditField
            app.DescriptionEditField = uieditfield(app.ConfigurationSettingsTab, 'text');
            app.DescriptionEditField.Editable = 'off';
            app.DescriptionEditField.Position = [103 461 178 22];

            % Create PulseSignalPaddingmsEditFieldLabel
            app.PulseSignalPaddingmsEditFieldLabel = uilabel(app.ConfigurationSettingsTab);
            app.PulseSignalPaddingmsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulseSignalPaddingmsEditFieldLabel.FontSize = 16;
            app.PulseSignalPaddingmsEditFieldLabel.Position = [339 494 195 22];
            app.PulseSignalPaddingmsEditFieldLabel.Text = 'Pulse Signal Padding (ms)';

            % Create PulseSignalPaddingmsEditField
            app.PulseSignalPaddingmsEditField = uieditfield(app.ConfigurationSettingsTab, 'numeric');
            app.PulseSignalPaddingmsEditField.ValueChangedFcn = createCallbackFcn(app, @PulseSignalPaddingmsEditFieldValueChanged, true);
            app.PulseSignalPaddingmsEditField.FontSize = 16;
            app.PulseSignalPaddingmsEditField.Position = [543 494 100 22];
            app.PulseSignalPaddingmsEditField.Value = 1;

            % Create DAQTypeDropDownLabel
            app.DAQTypeDropDownLabel = uilabel(app.ConfigurationSettingsTab);
            app.DAQTypeDropDownLabel.HorizontalAlignment = 'right';
            app.DAQTypeDropDownLabel.FontName = 'Tahoma';
            app.DAQTypeDropDownLabel.FontSize = 16;
            app.DAQTypeDropDownLabel.Position = [48 532 77 22];
            app.DAQTypeDropDownLabel.Text = 'DAQ Type';

            % Create DAQTypeDropDown
            app.DAQTypeDropDown = uidropdown(app.ConfigurationSettingsTab);
            app.DAQTypeDropDown.Items = {'ni', 'digilent'};
            app.DAQTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @DAQTypeDropDownValueChanged, true);
            app.DAQTypeDropDown.FontName = 'Tahoma';
            app.DAQTypeDropDown.FontSize = 14;
            app.DAQTypeDropDown.Position = [140 532 141 22];
            app.DAQTypeDropDown.Value = 'ni';

            % Create SampleRateEditFieldLabel
            app.SampleRateEditFieldLabel = uilabel(app.ConfigurationSettingsTab);
            app.SampleRateEditFieldLabel.HorizontalAlignment = 'right';
            app.SampleRateEditFieldLabel.FontSize = 16;
            app.SampleRateEditFieldLabel.Position = [463 536 98 22];
            app.SampleRateEditFieldLabel.Text = 'Sample Rate';

            % Create SampleRateEditField
            app.SampleRateEditField = uieditfield(app.ConfigurationSettingsTab, 'numeric');
            app.SampleRateEditField.ValueDisplayFormat = '%11.4d';
            app.SampleRateEditField.ValueChangedFcn = createCallbackFcn(app, @SampleRateEditFieldValueChanged, true);
            app.SampleRateEditField.FontSize = 16;
            app.SampleRateEditField.Position = [579 536 60 22];
            app.SampleRateEditField.Value = 40000;

            % Create StimulatorChannel1Panel
            app.StimulatorChannel1Panel = uipanel(app.ConfigurationSettingsTab);
            app.StimulatorChannel1Panel.Title = 'Stimulator Channel 1';
            app.StimulatorChannel1Panel.FontWeight = 'bold';
            app.StimulatorChannel1Panel.FontSize = 16;
            app.StimulatorChannel1Panel.Position = [13 196 229 169];

            % Create StimulatorEnableChannelDropDownLabel
            app.StimulatorEnableChannelDropDownLabel = uilabel(app.StimulatorChannel1Panel);
            app.StimulatorEnableChannelDropDownLabel.HorizontalAlignment = 'right';
            app.StimulatorEnableChannelDropDownLabel.FontSize = 16;
            app.StimulatorEnableChannelDropDownLabel.Position = [10 115 197 22];
            app.StimulatorEnableChannelDropDownLabel.Text = 'Stimulator Enable Channel';

            % Create TrigChan_1
            app.TrigChan_1 = uidropdown(app.StimulatorChannel1Panel);
            app.TrigChan_1.Items = {'Port0/Line0', 'Port0/Line1'};
            app.TrigChan_1.FontSize = 16;
            app.TrigChan_1.Position = [70 83 141 22];
            app.TrigChan_1.Value = 'Port0/Line0';

            % Create StimulatorChannelLabel
            app.StimulatorChannelLabel = uilabel(app.StimulatorChannel1Panel);
            app.StimulatorChannelLabel.HorizontalAlignment = 'right';
            app.StimulatorChannelLabel.FontSize = 16;
            app.StimulatorChannelLabel.Position = [13 37 195 22];
            app.StimulatorChannelLabel.Text = 'Stimulator Output Channel';

            % Create OutputChan_1
            app.OutputChan_1 = uidropdown(app.StimulatorChannel1Panel);
            app.OutputChan_1.Items = {'ao0', 'ao1', 'ao2', 'ao3'};
            app.OutputChan_1.FontSize = 16;
            app.OutputChan_1.Position = [69 12 140 22];
            app.OutputChan_1.Value = 'ao0';

            % Create StimulatorChannel2Panel
            app.StimulatorChannel2Panel = uipanel(app.ConfigurationSettingsTab);
            app.StimulatorChannel2Panel.Title = 'Stimulator Channel 2';
            app.StimulatorChannel2Panel.FontWeight = 'bold';
            app.StimulatorChannel2Panel.FontSize = 16;
            app.StimulatorChannel2Panel.Position = [256 196 231 169];

            % Create StimulatorEnableChannelDropDown_2Label
            app.StimulatorEnableChannelDropDown_2Label = uilabel(app.StimulatorChannel2Panel);
            app.StimulatorEnableChannelDropDown_2Label.HorizontalAlignment = 'right';
            app.StimulatorEnableChannelDropDown_2Label.FontSize = 16;
            app.StimulatorEnableChannelDropDown_2Label.Position = [10 116 197 22];
            app.StimulatorEnableChannelDropDown_2Label.Text = 'Stimulator Enable Channel';

            % Create TrigChan_2
            app.TrigChan_2 = uidropdown(app.StimulatorChannel2Panel);
            app.TrigChan_2.Items = {'Port0/Line0', 'Port0/Line1'};
            app.TrigChan_2.FontSize = 16;
            app.TrigChan_2.Position = [70 84 141 22];
            app.TrigChan_2.Value = 'Port0/Line1';

            % Create StimulatorOutputChannelDropDown_2Label
            app.StimulatorOutputChannelDropDown_2Label = uilabel(app.StimulatorChannel2Panel);
            app.StimulatorOutputChannelDropDown_2Label.HorizontalAlignment = 'right';
            app.StimulatorOutputChannelDropDown_2Label.FontSize = 16;
            app.StimulatorOutputChannelDropDown_2Label.Position = [13 37 195 22];
            app.StimulatorOutputChannelDropDown_2Label.Text = 'Stimulator Output Channel';

            % Create OutputChan_2
            app.OutputChan_2 = uidropdown(app.StimulatorChannel2Panel);
            app.OutputChan_2.Items = {'ao0', 'ao1', 'ao2', 'ao3'};
            app.OutputChan_2.FontSize = 16;
            app.OutputChan_2.Position = [69 13 140 22];
            app.OutputChan_2.Value = 'ao1';

            % Create SignalInputMonitoringPanel
            app.SignalInputMonitoringPanel = uipanel(app.ConfigurationSettingsTab);
            app.SignalInputMonitoringPanel.Title = 'Signal Input Monitoring';
            app.SignalInputMonitoringPanel.FontWeight = 'bold';
            app.SignalInputMonitoringPanel.FontSize = 16;
            app.SignalInputMonitoringPanel.Position = [12 18 649 103];

            % Create EnableInputreadingCheckBox
            app.EnableInputreadingCheckBox = uicheckbox(app.SignalInputMonitoringPanel);
            app.EnableInputreadingCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableInputreadingCheckBoxValueChanged, true);
            app.EnableInputreadingCheckBox.Text = 'Enable Input reading';
            app.EnableInputreadingCheckBox.FontSize = 16;
            app.EnableInputreadingCheckBox.Position = [16 17 180 31];

            % Create AnalogInputRecordingChannelDropDownLabel
            app.AnalogInputRecordingChannelDropDownLabel = uilabel(app.SignalInputMonitoringPanel);
            app.AnalogInputRecordingChannelDropDownLabel.HorizontalAlignment = 'right';
            app.AnalogInputRecordingChannelDropDownLabel.FontSize = 16;
            app.AnalogInputRecordingChannelDropDownLabel.Position = [379 41 238 22];
            app.AnalogInputRecordingChannelDropDownLabel.Text = 'Analog Input Recording Channel';

            % Create AnalogInputRecordingChannelDropDown
            app.AnalogInputRecordingChannelDropDown = uidropdown(app.SignalInputMonitoringPanel);
            app.AnalogInputRecordingChannelDropDown.Items = {'ai0'};
            app.AnalogInputRecordingChannelDropDown.FontSize = 16;
            app.AnalogInputRecordingChannelDropDown.Position = [474 9 140 22];
            app.AnalogInputRecordingChannelDropDown.Value = 'ai0';

            % Create SaveScanCheckBox
            app.SaveScanCheckBox = uicheckbox(app.SignalInputMonitoringPanel);
            app.SaveScanCheckBox.Text = 'Save Scan';
            app.SaveScanCheckBox.FontSize = 16;
            app.SaveScanCheckBox.Position = [14 47 180 31];

            % Create EventTriggerPanel
            app.EventTriggerPanel = uipanel(app.ConfigurationSettingsTab);
            app.EventTriggerPanel.Title = 'Event Trigger';
            app.EventTriggerPanel.FontWeight = 'bold';
            app.EventTriggerPanel.FontSize = 16;
            app.EventTriggerPanel.Position = [498 196 162 169];

            % Create TriggerVoltageDropDownLabel
            app.TriggerVoltageDropDownLabel = uilabel(app.EventTriggerPanel);
            app.TriggerVoltageDropDownLabel.HorizontalAlignment = 'right';
            app.TriggerVoltageDropDownLabel.FontSize = 16;
            app.TriggerVoltageDropDownLabel.Position = [33 115 113 22];
            app.TriggerVoltageDropDownLabel.Text = 'Trigger Voltage';

            % Create TriggerVoltageDropDown
            app.TriggerVoltageDropDown = uidropdown(app.EventTriggerPanel);
            app.TriggerVoltageDropDown.Items = {'3.3 V', '5 V'};
            app.TriggerVoltageDropDown.FontSize = 16;
            app.TriggerVoltageDropDown.Position = [60 84 86 22];
            app.TriggerVoltageDropDown.Value = '3.3 V';

            % Create TriggerChannelDropDownLabel
            app.TriggerChannelDropDownLabel = uilabel(app.EventTriggerPanel);
            app.TriggerChannelDropDownLabel.HorizontalAlignment = 'right';
            app.TriggerChannelDropDownLabel.FontSize = 16;
            app.TriggerChannelDropDownLabel.Position = [22 47 120 22];
            app.TriggerChannelDropDownLabel.Text = 'Trigger Channel';

            % Create TriggerChannelDropDown
            app.TriggerChannelDropDown = uidropdown(app.EventTriggerPanel);
            app.TriggerChannelDropDown.Items = {'ao1', 'ao2', 'ao3', 'port0/Line0', 'port0/Line1'};
            app.TriggerChannelDropDown.FontSize = 16;
            app.TriggerChannelDropDown.Position = [68 15 90 22];
            app.TriggerChannelDropDown.Value = 'ao3';

            % Create DisabledButton_1
            app.DisabledButton_1 = uibutton(app.ConfigurationSettingsTab, 'state');
            app.DisabledButton_1.ValueChangedFcn = createCallbackFcn(app, @DisabledButton_1ValueChanged, true);
            app.DisabledButton_1.Text = 'Disabled';
            app.DisabledButton_1.FontSize = 14;
            app.DisabledButton_1.FontWeight = 'bold';
            app.DisabledButton_1.Position = [72 164 100 24];

            % Create DisabledButton_2
            app.DisabledButton_2 = uibutton(app.ConfigurationSettingsTab, 'state');
            app.DisabledButton_2.ValueChangedFcn = createCallbackFcn(app, @DisabledButton_2ValueChanged, true);
            app.DisabledButton_2.Text = 'Disabled';
            app.DisabledButton_2.FontSize = 14;
            app.DisabledButton_2.FontWeight = 'bold';
            app.DisabledButton_2.Position = [324 165 100 24];

            % Create DisabledButton_3
            app.DisabledButton_3 = uibutton(app.ConfigurationSettingsTab, 'state');
            app.DisabledButton_3.Text = 'Disabled';
            app.DisabledButton_3.FontSize = 14;
            app.DisabledButton_3.FontWeight = 'bold';
            app.DisabledButton_3.Position = [522 164 100 24];

            % Create VirtualCheckBox
            app.VirtualCheckBox = uicheckbox(app.ConfigurationSettingsTab);
            app.VirtualCheckBox.ValueChangedFcn = createCallbackFcn(app, @VirtualCheckBoxValueChanged, true);
            app.VirtualCheckBox.Text = 'Virtual';
            app.VirtualCheckBox.Position = [542 459 76 26];

            % Create LogEditField
            app.LogEditField = uitextarea(app.DS8RInterfaceUIFigure);
            app.LogEditField.FontSize = 16;
            app.LogEditField.Position = [700 103 517 79];

            % Create OutputLampLabel
            app.OutputLampLabel = uilabel(app.DS8RInterfaceUIFigure);
            app.OutputLampLabel.HorizontalAlignment = 'right';
            app.OutputLampLabel.Position = [1124 618 42 22];
            app.OutputLampLabel.Text = 'Output';

            % Create OutputLamp
            app.OutputLamp = uilamp(app.DS8RInterfaceUIFigure);
            app.OutputLamp.Position = [1170 619 20 20];
            app.OutputLamp.Color = [0.651 0.651 0.651];

            % Create STARTButton
            app.STARTButton = uibutton(app.DS8RInterfaceUIFigure, 'push');
            app.STARTButton.ButtonPushedFcn = createCallbackFcn(app, @STARTButtonPushed, true);
            app.STARTButton.BackgroundColor = [0.8 0.8 0.8];
            app.STARTButton.FontSize = 18;
            app.STARTButton.Enable = 'off';
            app.STARTButton.Position = [759 26 189 55];
            app.STARTButton.Text = 'START';

            % Create STOPButton
            app.STOPButton = uibutton(app.DS8RInterfaceUIFigure, 'push');
            app.STOPButton.ButtonPushedFcn = createCallbackFcn(app, @STOPButtonPushed, true);
            app.STOPButton.BackgroundColor = [0.949 0.3137 0.3137];
            app.STOPButton.FontSize = 18;
            app.STOPButton.Enable = 'off';
            app.STOPButton.Position = [1017 26 189 55];
            app.STOPButton.Text = 'STOP';

            % Create LoadButton
            app.LoadButton = uibutton(app.DS8RInterfaceUIFigure, 'push');
            app.LoadButton.Enable = 'off';
            app.LoadButton.Position = [17 622 129 32];
            app.LoadButton.Text = 'Load';

            % Create SaveButton
            app.SaveButton = uibutton(app.DS8RInterfaceUIFigure, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Enable = 'off';
            app.SaveButton.Position = [157 622 129 32];
            app.SaveButton.Text = 'Save';

            % Create ConnectButton
            app.ConnectButton = uibutton(app.DS8RInterfaceUIFigure, 'push');
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectButtonPushed, true);
            app.ConnectButton.FontSize = 18;
            app.ConnectButton.Position = [963 614 100 30];
            app.ConnectButton.Text = 'Connect';

            % Create ConnecttofirstDAQdeviceseenLabel
            app.ConnecttofirstDAQdeviceseenLabel = uilabel(app.DS8RInterfaceUIFigure);
            app.ConnecttofirstDAQdeviceseenLabel.Position = [749 618 183 22];
            app.ConnecttofirstDAQdeviceseenLabel.Text = 'Connect to first DAQ device seen';

            % Show the figure after all components are created
            app.DS8RInterfaceUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DS8R_Stim_GUI_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.DS8RInterfaceUIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.DS8RInterfaceUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.DS8RInterfaceUIFigure)
        end
    end
end