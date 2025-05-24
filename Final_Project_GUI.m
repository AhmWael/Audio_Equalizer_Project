function Final_Project_GUI()
    % Create figure
    fig = uifigure('Name', 'Audio Equalizer', 'Position', [100 100 900 600]);

    %% --- File and Playback Panel ---
    filePanel = uipanel(fig, 'Title', 'Audio File & Playback', 'FontWeight', 'bold', 'Position', [20 500 860 80]);
    OpenfileButton = uibutton(filePanel, 'push', 'Position', [20 15 100 30], 'Text', 'Open File', 'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold');
    PlayButton = uibutton(filePanel, 'push', 'Position', [140 15 100 30], 'Text', 'Play', 'Enable', 'off', 'BackgroundColor', [0.2 0.8 0.2], 'FontWeight', 'bold');
    CustomButton = uibutton(filePanel, 'push', 'Position', [260 15 100 30], 'Text', 'Custom', 'Enable', 'off', 'BackgroundColor', [0.0 1.0 1.0], 'FontWeight', 'bold');
    AnalysisButton = uibutton(filePanel, 'push', 'Position', [380 15 120 30], 'Text', 'Show Analysis', 'Enable', 'off', 'BackgroundColor', [1.0, 1.0, 0.0], 'FontWeight', 'bold');
    ModeSwitch = uiswitch(filePanel, 'slider', 'Position', [650 15 60 30], 'Items', {'Standard', 'Custom'}, 'ItemsData', {'Standard', 'Custom'}, 'Value', 'Standard', 'FontWeight', 'bold', 'ValueChangedFcn', @(src, event)onModeSwitch());

    %% --- Filter Settings Panel ---
    filterPanel = uipanel(fig, 'Title', 'Filter Settings', 'FontWeight', 'bold', 'Position', [20 400 380 90]);

    % Multiplier input
    MultiplierField = uieditfield(filterPanel, 'numeric', 'Position', [250 45 40 22], 'Value', 1, 'Tooltip', 'Enter multiplier for Fs');

    % Multiply button
    MultiplyButton = uibutton(filterPanel, 'Text', '×', 'Position', [295 45 25 22], 'Tooltip', 'Multiply Fs by factor', 'ButtonPushedFcn', @(~,~)multiplyFs());

    uilabel(filterPanel, 'Position', [10 45 120 22], 'Text', 'Sampling Rate (Hz)');
    FsEditField = uieditfield(filterPanel, 'numeric', 'Position', [140 45 100 22], 'Value', 100, 'Editable', 'off');

    uilabel(filterPanel, 'Position', [10 15 120 22], 'Text', 'Filter Order');
    OrderEditField = uieditfield(filterPanel, 'numeric', 'Position', [140 15 100 22], 'Value', 2);

    function multiplyFs()
        factor = MultiplierField.Value;
        if isempty(factor) || ~isnumeric(factor) || factor <= 0
            uialert(fig, 'Multiplier must be a positive number.', 'Invalid Input');
            return;
        end
        effectiveFs = originalFs * factor;
        FsEditField.Value = effectiveFs; % Display only
    end



    %% --- Filter Type Panel ---
    typePanel = uipanel(fig, 'Title', 'Filter Type', 'FontWeight', 'bold', 'Position', [410 400 140 90]);

    FilterTypeButtonGroup = uibuttongroup(typePanel, 'Position', [10 5 100 60], 'Title', '', 'BorderType','none');
    FIRButton = uiradiobutton(FilterTypeButtonGroup, 'Text', 'FIR', 'Position', [10 30 100 20], 'Value', true);
    IIRButton = uiradiobutton(FilterTypeButtonGroup, 'Text', 'IIR', 'Position', [10 10 100 20]);

    %% --- Window Type Panel ---
    windowPanel = uipanel(fig, 'Title', 'Window / Design', 'FontWeight', 'bold', 'Position', [560 400 320 90]);

    uilabel(windowPanel, 'Position', [10 30 120 22], 'Text', 'Window Type');
    WindowTypeDropDown = uidropdown(windowPanel, 'Position', [140 30 150 22]);

    %% --- Equalizer Sliders Panel ---
    sliderPanel = uipanel(fig, 'Title', 'Equalizer Sliders (Gain in dB)', 'FontWeight', 'bold', 'Position', [20 20 860 370]);

    gainWarningLabel = uilabel(sliderPanel, 'Position', [250 320 400 22], 'Text', 'Gain changes won''t apply until you stop and replay.', 'FontColor', 'red', 'Visible', 'off');

    defaultBands = [0.01,200;200,500;500,800;800,1200;1200,3000;3000,6000;6000,12000;12000,16000;16000,20000];
    sliders = gobjects(9, 1);

    for i = 1:9
        x = 70*i + 60;
        sliders(i) = uislider(sliderPanel, 'Orientation', 'vertical', 'Limits', [0 20], 'Position', [x 80 3 200], 'Enable', 'off', 'Value', 0, 'ValueChangingFcn', @(src, event)gainChangeWarning());

        % Add label under each slider
        f1 = defaultBands(i,1) / 1000;
        f2 = defaultBands(i,2) / 1000;
        bandLabel = sprintf('%.1fk-%.1fk', f1, f2);

        uilabel(sliderPanel, 'Position', [x-25 50 80 22], 'HorizontalAlignment', 'center', 'Text', bandLabel);
    end

    %% Function: Show gain warning
    function gainChangeWarning()
        if isPlaying
            gainWarningLabel.Visible = 'on';
        end
    end

    function onModeSwitch()
        isCustomMode = strcmp(ModeSwitch.Value, 'Custom');
        updateCustomButtonState();
    end

    function updateCustomButtonState()
        if isFileLoaded && isCustomMode
            CustomButton.Enable = 'on';
        else
            CustomButton.Enable = 'off';
        end
    end


    % Initialize state
    audioData = [];
    sampleRate = 44100;
    filteredSignal = [];
    isPlaying = false;
    player = [];
    customBands = [];
    customGains = [];
    isCustomMode = false;
    isFileLoaded = false;
    originalFs = 44100;
    effectiveFs = 44100;
    filterResponses = struct(); % To store filter responses for analysis
    bandSignals = []; % To store individual band signals for analysis

    % Dropdown initializer
    function updateWindowDropdown()
        if IIRButton.Value
            WindowTypeDropDown.Items = {'Butterworth', 'Chebyshev I', 'Chebyshev II'};
            WindowTypeDropDown.Value = 'Butterworth';
        else
            WindowTypeDropDown.Items = {'Hamming', 'Hanning', 'Blackman'};
            WindowTypeDropDown.Value = 'Hamming';
        end
    end
    updateWindowDropdown();

    % Open File callback
    OpenfileButton.ButtonPushedFcn = @(~,~)openFile();
    function openFile()
        [file, path] = uigetfile('*.wav');
        if isequal(file, 0); return; end
        filename = fullfile(path, file);
        [audioData, originalFs] = audioread(filename);
        FsEditField.Value = originalFs;
        effectiveFs = originalFs;  % Initial value
        FsEditField.Editable = 'on';            % Enable editing now
        sampleRate = FsEditField.Value;         % Update internal variable

        PlayButton.Enable = 'on';
        CustomButton.Enable = 'on';
        %AnalysisButton.Enable = 'on';
        for i = 1:9; sliders(i).Enable = 'on'; end
        isFileLoaded = true;
        updateCustomButtonState();
    end

    % Play Button callback
    PlayButton.ButtonPushedFcn = @(~,~)playAudio();
    function playAudio()
        if isempty(audioData); return; end
        if isPlaying
            stop(player);
            isPlaying = false;
            PlayButton.Text = 'Play';
            PlayButton.BackgroundColor = [0.2 0.8 0.2];
        else
            processAudio();
            sampleRate = FsEditField.Value; % Update sampleRate from UI before play
            player = audioplayer(filteredSignal, effectiveFs);
            play(player);
            isPlaying = true;
            PlayButton.Text = 'Stop';
            PlayButton.BackgroundColor = [1.0 0.2 0.2];
            AnalysisButton.Enable = 'on';
            player.StopFcn = @(~,~)onStop();
        end
    end
    function onStop()
        isPlaying = false;
        PlayButton.Text = 'Play';
        gainWarningLabel.Visible = 'off';
        AnalysisButton.Enable = 'off';
    end

    %% Filter type switcher
    FilterTypeButtonGroup.SelectionChangedFcn = @(~,~)updateWindowDropdown();

    %% Custom dialog
    CustomButton.ButtonPushedFcn = @(~,~)showCustomDialog();
    function showCustomDialog()
        d = uifigure('Name', 'Custom Frequency Bands', 'Position', [100 100 420 400]);

        % Initialize table data: fixed first and last edge, middle bands blank
        defaultData = [
            0     NaN     0;
            NaN   NaN     0;
            NaN   NaN     0;
            NaN   NaN     0;
            NaN   20000   0
        ];

        t = uitable(d, 'Data', defaultData, 'Position', [20 100 380 200], 'ColumnName', {'Start Freq', 'End Freq', 'Gain'}, 'CellEditCallback', @validateCell);

        % Disable editing of 0 and 20000 cells
        editableMask = true(size(defaultData));
        editableMask(1,1) = false;   % first row, first column (0 Hz)
        editableMask(end,2) = false; % last row, second colun (20000 Hz)
        t.ColumnEditable = any(editableMask,1); % Needed for uitable compatibility

        uibutton(d, 'Text', '+ Add', 'Position', [20 60 100 22], 'BackgroundColor', [0 0.5 0], 'FontWeight', 'bold', 'FontColor', 'white', 'ButtonPushedFcn', @(~,~)addBand());
        uibutton(d, 'Text', '- Remove', 'Position', [140 60 100 22], 'BackgroundColor', [0.7 0 0], 'FontWeight', 'bold', 'FontColor', 'white', 'ButtonPushedFcn', @(~,~)removeBand());
        uibutton(d, 'Text', 'OK', 'Position', [260 20 100 22], 'BackgroundColor', [0 0.4470 0.7410], 'FontWeight', 'bold', 'FontColor', 'white', 'ButtonPushedFcn', @(~,~)onOK());
        uibutton(d, 'Text', 'Cancel', 'Position', [140 20 100 22], 'BackgroundColor', [0.6 0.6 0.6], 'FontWeight', 'bold', 'FontColor', 'white', 'ButtonPushedFcn', @(~,~)delete(d));


        % Lock cells from manual editing
        function validateCell(src, event)
            row = event.Indices(1);
            col = event.Indices(2);
            newData = event.NewData;

            % Protect locked cells (first start freq and last end freq)
            if (row == 1 && col == 1) || (row == size(src.Data,1) && col == 2)
                src.Data(row, col) = event.PreviousData;
                return;
            end

            % Handle linking logic
            data = src.Data;

            if col == 1 && row > 1
                % User changed start freq of current band → update end freq of previous
                data(row-1, 2) = newData;
            elseif col == 2 && row < size(data,1)
                % User changed end freq of current band → update start freq of next
                data(row+1, 1) = newData;
            end

            % Write updated table
            src.Data = data;
        end


        function addBand()
            if size(t.Data, 1) >= 10
                uialert(d, 'Maximum 10 bands allowed', 'Limit'); return;
            end
            data = t.Data;

            % Step 1: Update second-to-last row's end frequency to NaN
            data(end,2) = NaN;

            % Step 2: Add new last row with end frequency = 20000
            newRow = [NaN 20000 0];
            t.Data = [data; newRow];

            % Update editable mask (re-enable second-to-last, lock new last row)
            editableMask = true(size(t.Data));
            editableMask(1,1) = false;                % Lock first Start Freq (0 Hz)
            editableMask(end,2) = false;              % Lock last End Freq (20000 Hz)
            t.ColumnEditable = any(editableMask,1);   % Refresh editability
        end

        function removeBand()
            if size(t.Data, 1) <= 5
                uialert(d, 'Minimum 5 bands required', 'Limit'); return;
            end
            data = t.Data;

            % Remove second-to-last row
            data(end-1,:) = [];

            % Restore 20000 to last row and lock
            data(end,2) = 20000;
            t.Data = data;

            % Update editable mask
            editableMask = true(size(t.Data));
            editableMask(1,1) = false;
            editableMask(end,2) = false;
            t.ColumnEditable = any(editableMask,1);
        end

        function onOK()
            data = t.Data;
            
            % Force first start freq to 0.01
            data(1,1) = 0.01;

            % Validate
            if data(end,2) ~= 20000 || any(isnan(data(:,1))) || any(isnan(data(:,2))) || any(diff(data(:,1)) <= 0)
                uialert(d, 'Invalid band configuration', 'Error'); return;
            end

            customBands = data(:,1:2);
            customGains = data(:,3);
            isCustomMode = true;
            delete(d);
        end

    end

    %% Analysis Button callback
    AnalysisButton.ButtonPushedFcn = @(~,~)showAnalysis();
    function showAnalysis()
        if isempty(audioData)
            uialert(fig, 'Please load an audio file first', 'Error');
            return;
        end
        
        if isempty(filterResponses)
            uialert(fig, 'Please process the audio first (click Play)', 'Error');
            return;
        end
        
        % Desired figure size
        figWidth = 1000;
        figHeight = 700;

        % Get screen size
        screenSize = get(0, 'ScreenSize');  % [left bottom width height]

        % Calculate centered position
        figX = (screenSize(3) - figWidth) / 2;
        figY = (screenSize(4) - figHeight) / 2;

        % Create analysis figure with centered position
        analysisFig = uifigure('Name', 'Filter Analysis', ...
                          'Position', [figX, figY, figWidth, figHeight]);
        
        % Create tab group
        tabGroup = uitabgroup(analysisFig, 'Position', [20 20 960 660]);
        
        % Add tabs for each band
        numBands = length(filterResponses);
        for bandIdx = 1:numBands
            tab = uitab(tabGroup, 'Title', sprintf('Band %d: %.0f-%.0f Hz', bandIdx, filterResponses(bandIdx).band(1), filterResponses(bandIdx).band(2)));
            
            % Create UI axes for the plots
            ax1 = uiaxes(tab, 'Position', [20 360 450 250]);
            plot(ax1, filterResponses(bandIdx).freq, abs(filterResponses(bandIdx).H));
            title(ax1, 'Magnitude Response');
            xlabel(ax1, 'Frequency (Hz)');
            ylabel(ax1, 'Magnitude');
            grid(ax1, 'on');
            
            ax2 = uiaxes(tab, 'Position', [500 360 450 250]);
            plot(ax2, filterResponses(bandIdx).freq, angle(filterResponses(bandIdx).H)*180/pi);
            title(ax2, 'Phase Response');
            xlabel(ax2, 'Frequency (Hz)');
            ylabel(ax2, 'Phase (degrees)');
            grid(ax2, 'on');
            
            ax3 = uiaxes(tab, 'Position', [20 60 300 250]);
            plot(ax3, filterResponses(bandIdx).impulse);
            title(ax3, 'Impulse Response');
            xlabel(ax3, 'Samples');
            ylabel(ax3, 'Amplitude');
            grid(ax3, 'on');
            
            ax4 = uiaxes(tab, 'Position', [350 60 300 250]);
            plot(ax4, filterResponses(bandIdx).step);
            title(ax4, 'Step Response');
            xlabel(ax4, 'Samples');
            ylabel(ax4, 'Amplitude');
            grid(ax4, 'on');
            
            ax5 = uiaxes(tab, 'Position', [680 60 270 250]);
            % Compute poles and zeros
            z = roots(filterResponses(bandIdx).num);
            p = roots(filterResponses(bandIdx).den);

            % Plot unit circle
            theta = linspace(0, 2*pi, 1000);
            plot(ax5, cos(theta), sin(theta), 'k--'); 
            hold(ax5, 'on');

            % Plot zeros and poles
            plot(ax5, real(z), imag(z), 'o', 'MarkerSize', 8, 'DisplayName', 'Zeros');
            plot(ax5, real(p), imag(p), 'x', 'MarkerSize', 8, 'DisplayName', 'Poles');

            % Style plot
            axis(ax5, 'equal');
            xlim(ax5, [-1.5 1.5]);
            ylim(ax5, [-1.5 1.5]);
            grid(ax5, 'on');
            xlabel(ax5, 'Real');
            ylabel(ax5, 'Imaginary');
            title(ax5, 'Pole-Zero Plot');
            legend(ax5, 'show');
            hold(ax5, 'off');

        end
        
        % Add tab for original and filtered signals
        signalTab = uitab(tabGroup, 'Title', 'Signal Analysis');
        
        % Time domain plots
        ax6 = uiaxes(signalTab, 'Position', [20 360 450 250]);
        plot(ax6, audioData);
        title(ax6, 'Original Signal (Time Domain)');
        xlabel(ax6, 'Samples');
        ylabel(ax6, 'Amplitude');
        grid(ax6, 'on');
        
        ax7 = uiaxes(signalTab, 'Position', [500 360 450 250]);
        plot(ax7, filteredSignal);
        title(ax7, 'Filtered Signal (Time Domain)');
        xlabel(ax7, 'Samples');
        ylabel(ax7, 'Amplitude');
        grid(ax7, 'on');
        
        % Frequency domain plots
        n = length(audioData);
        x_axis = (-n/2:n/2-1)*(sampleRate/n);
        x_axis_new = (-n/2:n/2-1)*(effectiveFs/n);
        
        ax8 = uiaxes(signalTab, 'Position', [20 60 450 250]);
        stem(ax8, x_axis, abs(fftshift(fft(audioData))));
        title(ax8, 'Original Signal (Frequency Domain)');
        xlabel(ax8, 'Frequency (Hz)');
        ylabel(ax8, 'Magnitude');
        grid(ax8, 'on');
        
        ax9 = uiaxes(signalTab, 'Position', [500 60 450 250]);
        stem(ax9, x_axis_new, abs(fftshift(fft(filteredSignal))));
        title(ax9, 'Filtered Signal (Frequency Domain)');
        xlabel(ax9, 'Frequency (Hz)');
        ylabel(ax9, 'Magnitude');
        grid(ax9, 'on');
    end

    % Audio processing
    function processAudio()
        filterOrder = OrderEditField.Value;
        sampleRate = FsEditField.Value;
        if IIRButton.Value
            switch WindowTypeDropDown.Value
                case 'Butterworth'; filterType = 4;
                case 'Chebyshev I'; filterType = 5;
                case 'Chebyshev II'; filterType = 6;
            end
        else
            switch WindowTypeDropDown.Value
                case 'Hamming'; filterType = 1;
                case 'Hanning'; filterType = 2;
                case 'Blackman'; filterType = 3;
            end
        end

        if isCustomMode
            k = size(customBands, 1);
            bands = customBands;
            gains = customGains;
        else
            k = 9;
            bands = [0.01,200;200,500;500,800;800,1200;1200,3000;3000,6000;6000,12000;12000,16000;16000,20000];
            gains = arrayfun(@(s)s.Value, sliders);
        end

        % Ensure gains are positive (0 or more)
        gains = max(gains, 0);
        gains = 10.^(gains/20);

        y = zeros(k, length(audioData));
        filterResponses = struct('num', {}, 'den', {}, 'H', {}, 'freq', {}, 'impulse', {}, 'step', {}, 'band', {});
        
        % Create test signals for analysis
        step_input = ones(1, min(originalFs, 300));
        impulse_input = [1 zeros(1, min(originalFs-1, 300))];
        
        for i = 1:k
            Wn = [bands(i,1) bands(i,2)]*2/originalFs;
            if any(Wn >= 1), Wn(Wn>=1) = 0.999; end % prevent error for normalized freq > 1
            switch filterType
                case 1; num = fir1(filterOrder, Wn, 'bandpass', hamming(filterOrder+1)); den = 1;
                case 2; num = fir1(filterOrder, Wn, 'bandpass', hanning(filterOrder+1)); den = 1;
                case 3; num = fir1(filterOrder, Wn, 'bandpass', blackman(filterOrder+1)); den = 1;
                case 4; [num, den] = butter(filterOrder, Wn, 'bandpass');
                case 5; [num, den] = cheby1(filterOrder, 1, Wn, 'bandpass');
                case 6; [num, den] = cheby2(filterOrder, 40, Wn, 'bandpass');
            end
            
            % Store filter responses for analysis
            [H, freq] = freqz(num, den, originalFs/2, originalFs);
            step = filter(num, den, step_input);
            impulse = filter(num, den, impulse_input);
            
            filterResponses(i).num = num;
            filterResponses(i).den = den;
            filterResponses(i).H = H;
            filterResponses(i).freq = freq;
            filterResponses(i).impulse = impulse;
            filterResponses(i).step = step;
            filterResponses(i).band = [bands(i,1), bands(i,2)];
            
            y(i,:) = gains(i) * filter(num, den, audioData);
        end
        bandSignals = y; % Store individual band signals
        filteredSignal = sum(y, 1)';
        audiowrite('equalized_output.wav', filteredSignal, effectiveFs);
        audiowrite('equalized_output_4x.wav', filteredSignal, effectiveFs*4);
        audiowrite('equalized_output_half.wav', filteredSignal, effectiveFs/2);
    end
end