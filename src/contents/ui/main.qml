/**
 * OctoPrint Monitor
 *
 * Plasmoid to monitor OctoPrint instance and print job progress.
 *
 * @author    Marcin Orlowski <mail (#) marcinOrlowski (.) com>
 * @copyright 2020 Marcin Orlowski
 * @license   http://www.opensource.org/licenses/mit-license.php MIT
 * @link      https://github.com/MarcinOrlowski/octoprint-monitor
 */

import QtQuick 2.1
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import "../js/utils.js" as Util

Item {
    id: main

    Plasmoid.compactRepresentation: CompactRepresentation {}
    Plasmoid.fullRepresentation: FullRepresentation {}

    // ------------------------------------------------------------------------------------------------------------------------

    // Printer state flags
    property bool pf_cancelling: false		// working
    property bool pf_closedOrError: false	// error
    property bool pf_error: false			// error
    property bool pf_finishing: false		// working
    property bool pf_operational: false		// idle
    property bool pf_paused: false			// paused
    property bool pf_pausing: false			// working
    property bool pf_printing: false		// working
    property bool pf_ready: false			// idle
    property bool pf_resuming: false		// working

    // printer state
    property string printer_state: ""

    // Bed temperature
    property double p_bed_actual: 0
    property double p_bed_offset: 0
    property double p_bed_target: 0

    // Hotend temperature
    property double p_he0_actual: 0
    property double p_he0_offset: 0
    property double p_he0_target: 0

    // True if printer is connected to OctoPrint
    property bool printerConnected: false

    // ------------------------------------------------------------------------------------------------------------------------

    // Job related stats (if any in progress)
    property string jobState: "N/A"
    property string jobStateDescription: ""
    property string jobFileName: ""
    property double jobCompletion: 0

    property string jobPrintTime: ""
	property string jobPrintStartStamp: ""
	property string jobPrintTimeLeft: ""

    // Indicates if print job is currently in progress.
	property bool jobInProgress: false

    // ------------------------------------------------------------------------------------------------------------------------

    // Indicates we were able to successfuly connect to OctoPrint API
    property bool apiConnected: false

    // ------------------------------------------------------------------------------------------------------------------------

    property bool firstApiRequest: true

    /*
    ** State fetching timer. We fetch printer state first and job state only
    ** if there's any ongoing.
    */
	Timer {
		id: mainTimer

        interval: plasmoid.configuration.statusPollInterval * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            getPrinterStateFromApi();

            // First time we need to fire both requests unconditionally, otherwise
            // job state request will neede to wait for another timer trigger, causing
            // odd delay in widget update.
            if (main.firstApiRequest) {
                main.firstApiRequest = false;
                getJobStateFromApi();
            } else {
                // Do not query Job state if we can tell there's no running job
                var buckets = [ main.bucket_error, main.bucket_idle, main.bucket_disconnected ];
                if (buckets.includes(getPrinterStateBucket()) === false) {
                    getJobStateFromApi();
                }
            }
        }
	}

    // ------------------------------------------------------------------------------------------------------------------------

    // Printer status buckets
    property string bucket_unknown: "unknown"
    property string bucket_working: "working"
    property string bucket_paused: "paused"
    property string bucket_error: "error"
    property string bucket_idle: "idle"
    property string bucket_disconnected: "disconnected"

    /*
    ** Returns name of printer state's bucket.
    **
    ** Returns:
    **	string: printer state bucket name
    */
    function getPrinterStateBucket() {
        var bucket = undefined;

        if ( main.pf_cancelling || main.pf_finishing || main.pf_printing || main.pf_pausing ) {
            bucket = main.bucket_working;
        } else if ( main.pf_closedOrError || main.pf_error ) {
            bucket = main.bucket_error;
        } else if ( main.pf_operational || main.pf_ready ) {
            bucket = main.bucket_idle;
        } else if ( main.pf_paused ) {
            bucket = main.bucket_paused;
        }

        if (bucket == undefined) {
            bucket = main.bucket_disconnected;
        }

        return bucket;
    }

    // ------------------------------------------------------------------------------------------------------------------------

    /*
    ** Checks if current printer status flags indicate there's actually print in progress.
    **
    ** Returns:
    **	bool
    */
    function isJobInProgress() {
        var result = main.pf_printing || main.pf_paused || main.pf_resuming;
        return result;
    }

    /*
    ** Checks if current printer status flags indicate device is offline or not.
    **
    ** Returns:
    **	bool
    */
    function isPrinterConnected() {
        return  main.pf_cancelling
             || main.pf_error
             || main.pf_finishing
             || main.pf_operational
             || main.pf_paused
             || main.pf_pausing
             || main.pf_printing
             || main.pf_ready
             || main.pf_resuming
//           || main.pf_closedOrError
        ;
    }

    // ------------------------------------------------------------------------------------------------------------------------

    property string octoState: "connecting"
    property string octoStateDescription: 'Connecting to OctoPrint API.'
    property string lastOctoStateChangeStamp: ""
    property string previousOctoState: ""
    property string octoStateIcon: plasmoid.file("", "images/state-unknown.png")

    function updateOctoStateDescription() {
        var desc = main.jobStateDescription;
        if (desc == '') {
            switch(main.octoState) {
                case bucket_unknown: desc = 'Unable to determine root cause.'; break;
                case bucket_paused: desc = 'Print job is PAUSED now.'; break;
                case bucket_idle: desc = 'Printer is operational and idle.'; break;
                case bucket_disconnected: desc = 'OctoPrint is not connected to the printer.'; break;
    //            case bucket_working: ""
    //            case bucket_error: "error"
                case 'unavailable': desc = 'Unable to connect to OctoPrint API.'; break;
                case 'connecting': desc = 'Connecting to OctoPrint API.'; break;
            }
        }

        main.octoStateDescription = desc;
    }

    function updateOctoState() {
        // calculate new octoState. If different from previous one, check what happened
        // (i.e. was printing is idle) -> print successful

        var jobInProgress = false;
        var printerConnected = isPrinterConnected();
        var state = getPrinterStateBucket();

        if (main.apiConnected) {
            jobInProgress = isJobInProgress();
            if (jobInProgress && main.jobState == "printing") {
                state = main.jobState;
            }
        } else {
            state = 'unavailable';

        }

        main.jobInProgress = jobInProgress;
        main.printerConnected = printerConnected;

        if (state != octoState) {
//            console.debug('OctoState Changed: new: "' + state + '", previous: "' + octoState + '", before: "' + previousOctoState + '"');
            main.previousOctoState = main.octoState
            main.octoState = state;
            updateOctoStateDescription();

            main.lastOctoStateChangeStamp = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat);

            // FIXME :Icon is currently always based on printer state
            main.octoStateIcon = getOctoStateIcon();
        }
    }

	/*
	** Returns path to icon representing current Octo state (based on
	** printer state bucket)
	**
	** Returns:
	**	string: path to plasmoid's icon file
	*/
	function getOctoStateIcon() {
	    var bucket = 'dead';
	    if (main.apiConnected) {
            bucket = getPrinterStateBucket();
        }
        return plasmoid.file("", "images/state-" + bucket + ".png");
	}

    // ------------------------------------------------------------------------------------------------------------------------

    /*
    ** Returns instance of XMLHttpRequest, configured for OctoPrint doing Api request.
    ** Throws Error if API URL or access key is not configured.
    **
    ** Returns:
    **  Configured instance of XMLHttpRequest.
    */
    function getXhr(req) {
        var apiUrl = plasmoid.configuration.api_url;
        var apiKey = plasmoid.configuration.api_key;

		if ( apiUrl + apiKey == "" ) {
		    throw new Error('Error: API access is not configured.');
		}

        var xhr = new XMLHttpRequest();
        var url = apiUrl + "/" + req;
        xhr.open('GET', url);
        xhr.setRequestHeader("Host", apiUrl);
        xhr.setRequestHeader("X-Api-Key", apiKey);

        return xhr;
    }

    // ------------------------------------------------------------------------------------------------------------------------

    /*
    ** Requests job status from OctoPrint and process the response.
	**
	** Returns:
	**	void
    */
	function getJobStateFromApi() {
	    var xhr = getXhr('job');

        xhr.onreadystatechange = (function () {
            // We only care about DONE readyState.
            if (xhr.readyState !== 4) {
                return;
            }

            // Ensure we managed to talk to the API
            main.apiConnected = (xhr.status !== 0);

            if (xhr.status !== 0) {
//            console.debug('ResponseText: "' + xhr.responseText + '"');
                try {
                    parseJobStatusResponse(JSON.parse(xhr.responseText));
                } catch (error) {
                    console.debug('Error handling API job state response.');
                    console.debug(error);
//                    console.debug('ResponseText: ' + xhr.responseText);
                }
            }
            updateOctoState();
        });
        xhr.send();
    }

	/*
	** Parses printing job status JSON response object.
	**
	** Arguments:
	**	resp: response JSON object
	**
	** Returns:
	**	void
	*/
	function parseJobStatusResponse(resp) {
		var state = resp.state.split(/[ ,]+/)[0];

		main.jobState = state.toLowerCase();

		var stateSplit = resp.state.match(/(.+)\s+\((.*)\)/)
		main.jobStateDescription = (stateSplit !== null) ? stateSplit[2] : '';
		updateOctoStateDescription();

		main.jobFileName = Util.getString(resp.job.file.display);

		if (Util.isVal(resp.progress.completion)) {
        	main.jobCompletion = Util.roundFloat(resp.progress.completion);
		} else {
			main,jobCompletion = 0;
		}

		var jobPrintTime = resp.progress.printTime
		if (Util.isVal(jobPrintTime)) {
			main.jobPrintTime = Util.secondsToString(jobPrintTime)
		} else {
			main.jobPrintTime = "???"
		}

		var printTimeLeft = resp.progress.printTimeLeft
		if (Util.isVal(printTimeLeft)) {
			main.jobPrintTimeLeft = Util.secondsToString(printTimeLeft)
		} else {
			main.jobPrintTimeLeft = "???"
		}
	}

    // ------------------------------------------------------------------------------------------------------------------------

    /*
    ** Requests printer status from OctoPrint and process the response.
	**
	** Returns:
	**	void
    */
    function getPrinterStateFromApi() {
        var xhr = getXhr('printer');

        xhr.onreadystatechange = (function () {
            // We only care about DONE readyState.
            if (xhr.readyState !== 4) {
                return;
            }

            // Ensure we managed to talk to the API
            main.apiConnected = (xhr.status !== 0);
            if (xhr.status !== 0) {
                try {
                    parsePrinterStateResponse(JSON.parse(xhr.responseText));
                } catch (error) {
                    main.pf_cancelling = false;
                    main.pf_closedOrError = false;
                    main.pf_error = false;
                    main.pf_finishing = false;
                    main.pf_operational = false;
                    main.pf_paused = false;
                    main.pf_pausing = false;
                    main.pf_printing = false
                    main.pf_ready = false;
                    main.pf_resuming = false;

                    // This is nasty hack for lame OctoPrint API that returns plain string
                    // when printer is disconnected instead of proper JSON formatted response.
                    if (xhr.responseText != 'Printer is not operational') {
                        console.debug('Error handling API printer state response.');
                        console.debug('Error caught: ' + error);
//                        console.debug('ResponseText: "' + xhr.responseText + '"');

                        main.pf_error = true;
                    }
                }
            }
            updateOctoState();
        });
        xhr.send();
    }

	/*
	** Parses printer status JSON response object.
	**
	** Arguments:
	**	resp: response JSON object
	**
	** Returns:
	**	void
	*/
	function parsePrinterStateResponse(resp) {
		main.pf_cancelling = resp.state.flags.cancelling;
		main.pf_closedOrError = resp.state.flags.closedOrError;
		main.pf_error = resp.state.flags.error;
		main.pf_finishing = resp.state.flags.finishing;
		main.pf_operational = resp.state.flags.operational;
		main.pf_paused = resp.state.flags.paused;
		main.pf_pausing = resp.state.flags.pausing;
		main.pf_printing = resp.state.flags.printing;
		main.pf_ready = resp.state.flags.ready;
		main.pf_resuming = resp.state.flags.resuming;

		// Textural representation of printer state as returned by API
		main.printer_state = resp.state.text;

		// temepratures
		main.p_bed_actual = Util.getFloat(resp.temperature.bed.actual);
		main.p_bed_offset = Util.getFloat(resp.temperature.bed.offset);
		main.p_bed_target = Util.getFloat(resp.temperature.bed.target);

		// hot-ends
		// FIXME: check for more than one
		main.p_he0_actual = Util.getFloat(resp.temperature.tool0.actual);
		main.p_he0_offset = Util.getFloat(resp.temperature.tool0.offset);
		main.p_he0_target = Util.getFloat(resp.temperature.tool0.target);
	}

    // ------------------------------------------------------------------------------------------------------------------------

}
