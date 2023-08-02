package com.zemasterkrom.lddiscovery.configuration.health;

import org.springframework.beans.BeansException;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.context.event.ApplicationEnvironmentPreparedEvent;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.context.ApplicationListener;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.env.Environment;
import org.springframework.lang.NonNull;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;


/**
 * Unfortunately, Windows does not handle termination signals very well.
 * Just to be sure that all resources are cleaned up when the application exits, this class periodically checks for the existence of a temporary file.
 * If not found, the application will shut down itself.
 * It is useful for the PowerShell runner script where multiple processes are started in the console.
 */
@Order(Ordered.HIGHEST_PRECEDENCE)
public class WinTerminationSignalHandler implements ApplicationListener<ApplicationEnvironmentPreparedEvent>, ApplicationContextAware {

    /**
     * Asynchronous task scheduler that allows the class to run checks every second
     */
    private final ScheduledExecutorService scheduler;

    /**
     * Spring application context
     */
    private ApplicationContext applicationContext;

    /**
     * Temporary file that serves as a marker to detect if the application is closed
     */
    private File tmpFile;

    /**
     * Constructor of the Windows termination signal handle.
     * Initializes the scheduler.
     */
    public WinTerminationSignalHandler() {
        this.applicationContext = null;
        this.scheduler = Executors.newScheduledThreadPool(1);
        this.tmpFile = new File("");
    }

    /**
     * Logic executed only on a Windows OS.
     * Checks every second if the temporary file still exists, otherwise stops the Spring application.
     * If the temporary file does not exist, the periodic check is ignored and only the Windows mechanism will be used to stop / kill the process.
     *
     * @param event Event triggered when the environment is prepared and ready to be used
     */
    @Override
    public void onApplicationEvent(ApplicationEnvironmentPreparedEvent event) {
        Environment environment = event.getEnvironment();

        String tmpRunnerFile = environment.getProperty("TMP_RUNNER_FILE", "");
        String tmpDir = environment.getProperty("java.io.tmpdir", "");
        String os = environment.getProperty("os.name", "");

        // Checks are only needed for Windows : execute the check every second and exit if the file no longer exists
        if (os.toLowerCase().contains("win") && !tmpRunnerFile.isBlank() && !tmpDir.isBlank()) {
            try {
                this.tmpFile = new File(tmpDir + "\\" + tmpRunnerFile);

                if (this.tmpFile.createNewFile()) {
                    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                        this.scheduler.shutdown();
                        this.scheduler.shutdownNow();
                    }));

                    this.scheduler.scheduleAtFixedRate(() -> {
                        if (!this.tmpFile.exists()) {
                            if (this.applicationContext != null) {
                                System.exit(SpringApplication.exit(this.applicationContext, () -> 130));
                            } else {
                                System.exit(130);
                            }
                        }
                    }, 0, 1, TimeUnit.SECONDS);
                } else {
                    System.err.println("Failed to create the " + this.tmpFile.getAbsolutePath() + " temporary file");
                }
            } catch (IOException e) {
                System.err.println(e.getMessage());
            }
        }

    }

    /**
     * Allows to retrieve the application context in order to stop the application gracefully
     *
     * @param applicationContext Spring application context
     */
    @Override
    public void setApplicationContext(@NonNull ApplicationContext applicationContext) throws BeansException {
        this.applicationContext = applicationContext;
    }

}
