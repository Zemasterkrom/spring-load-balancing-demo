import { Component, EventEmitter, Input, Output } from '@angular/core';
import { VideoGame } from '../types/videogame.type';
import { Router } from '@angular/router';

@Component({
  selector: 'video-game-card',
  templateUrl: './card.component.html',
  styleUrls: ['./card.component.css']
})
export class CardComponent{
  // Jeu vidéo associé à la carte descriptive
  private _videoGame: VideoGame;

  // Emetteur d'un événement de suppression pour un jeu vidéo
  private readonly _delete$: EventEmitter<VideoGame>;

  /**
   * Constructeur de la carte de description du jeu vidéo
   * @param _router Permet de gérer les routes et redirections
   */
  constructor(private _router: Router) {
    this._videoGame = {} as VideoGame;
    this._delete$ = new EventEmitter<VideoGame>();
  }

  /**
   * Retourner le jeu vidéo associé à la carte descriptive
   */
  get videoGame(): VideoGame {
    return this._videoGame;
  }

  @Input()
  set videoGame(person: VideoGame) {
    this._videoGame = person;
  }

  @Output('deleteVideoGame') get delete$(): EventEmitter<VideoGame> {
    return this._delete$;
  }

  /**
   * Supprimer le jeu vidéo associé à la carte en émettant un événement pour traitement sur un composat parent
   * @param vg Jeu vidéo à supprimer
   */
  delete(vg: VideoGame): void {
    this._delete$.emit(vg);
  }
}
