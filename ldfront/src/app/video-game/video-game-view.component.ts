import {Component, OnInit} from '@angular/core';
import { VideoGame } from '../shared/types/videogame.type';
import { VideoGameService } from '../shared/services/video-game.service';
import { filter, merge, mergeMap } from 'rxjs';
import {ActivatedRoute, Router} from '@angular/router';

@Component({
  selector: 'video-game',
  templateUrl: './video-game-view.component.html',
  styleUrls: ['./video-game-view.component.css']
})
export class VideoGameViewComponent implements OnInit {
  // Jeu vidéo passé à une carte descriptive
  private _videoGame: VideoGame;

  /**
   * Constructeur d'une vue de jeu vidéo.
   * Une vue est associée à une carte qui passe le jeu vidéo à un enfant (la carte de description)
   * @param _router Permet de gérer les routes et redirections
   * @param _videoGamesService Service des jeux vidéo
   * @param _route Récupérer la route actuelle afin de récupérer l'identifiant indiqué du jeu vidéo
   */
  constructor(private _router: Router, private _videoGamesService: VideoGameService, private _route: ActivatedRoute) {
    this._videoGame = {} as VideoGame;
  }

  /**
   * Retourner le jeu vidéo associé à la vue
   */
  get videoGame(): VideoGame {
    return this._videoGame;
  }

  /**
   * Récupérer l'identifiant dans la route afin d'afficher le jeu vidéo correspondant (si existant).
   * S'il n'existe pas, l'utilisateur est renvoyé à l'accueil.
   */
  ngOnInit(): void {
    merge(
      this._route.params.pipe(
        filter((params: any) => !!params.id),
        mergeMap((params: any) => this._videoGamesService.fetchOne(params.id))
      )
    )
      .subscribe({
        next: (vg: VideoGame | undefined) => this._showVideoGame(vg),
        error: () => {this._router.navigate(['/video-games/all'])}
      });
  }

  /**
   * Afficher le jeu vidéo (si trouvé)
   * @param vg Jeu vidéo
   */
  private _showVideoGame(vg: VideoGame | undefined) {
    if (vg) {
      this._videoGame = vg;
    } else {
      this._router.navigate(['/video-games/all']);
    }
  }
}
