import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import { VideoGamesComponent } from './video-games/video-games.component';
import { VideoGameUpdateComponent } from './update/video-game-update.component';
import { VideoGameViewComponent } from './video-game/video-game-view.component';

// Routes pour l'accueil, la modification, la vue d'un jeu vidéo
const routes: Routes = [
  { path: '', redirectTo: 'video-games/all', pathMatch: 'full' },
  { path: 'video-games', redirectTo: 'video-games/all', pathMatch: 'full' },
  { path: 'video-games/all', component: VideoGamesComponent },
  { path: 'video-games/modify/:id', component: VideoGameUpdateComponent },
  { path: 'video-games/:id', component: VideoGameViewComponent }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, {onSameUrlNavigation: 'reload'})],
  exports: [RouterModule]
})
export class AppRoutingModule { }
