import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatCardModule } from '@angular/material/card';
import { AppComponent } from './app.component';
import { VideoGameHomeComponent } from './home/video-game-home.component';
import { VideoGameViewComponent } from './video-game/video-game-view.component';
import { HttpClientModule } from '@angular/common/http';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { AppRoutingModule } from './app-routing.module';
import { VideoGamesComponent } from './video-games/video-games.component';
import { CardComponent } from './shared/card/card.component';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatDialogModule } from '@angular/material/dialog';
import { DialogComponent } from './shared/dialog/dialog.component';
import { VideoGameFormComponent } from './shared/form/video-game-form.component';
import { ReactiveFormsModule } from '@angular/forms';
import { VideoGameUpdateComponent } from './update/video-game-update.component';

// Déclaration des imports nécessaires pour faire fonctionner l'application, principalement les composants d'animation et les composants créés (declarations) importés par AppComponent
@NgModule({
  declarations: [AppComponent, VideoGameHomeComponent, VideoGameViewComponent, VideoGamesComponent, CardComponent, DialogComponent, VideoGameFormComponent, VideoGameUpdateComponent],
  imports: [
    BrowserModule,
    BrowserAnimationsModule,
    ReactiveFormsModule,
    HttpClientModule,
    MatToolbarModule,
    MatCardModule,
    MatButtonModule,
    MatCheckboxModule,
    MatIconModule,
    MatListModule,
    MatDialogModule,
    MatInputModule,
    MatFormFieldModule,
    AppRoutingModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule {
}
