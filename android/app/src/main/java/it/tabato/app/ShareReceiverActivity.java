package it.tabato.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/**
 * Punto di ingresso invisibile per le condivisioni di sistema (ACTION_SEND). Il sistema avvia le
 * destinazioni di condivisione nel task dell'app che condivide (es. Amazon), quindi TabaTo
 * comparirebbe "dentro" quell'app. Qui il testo condiviso viene inoltrato a MainActivity in un
 * nuovo task proprio (FLAG_ACTIVITY_NEW_TASK) e questa activity termina subito.
 */
public class ShareReceiverActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent source = getIntent();
        Intent forward = new Intent(this, MainActivity.class);
        forward.setAction(Intent.ACTION_SEND);
        forward.setType(source.getType());
        if (source.getExtras() != null) {
            forward.putExtras(source.getExtras());
        }
        forward.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(forward);
        finish();
    }
}
