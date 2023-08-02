import { Component, Inject, Optional } from '@angular/core';
import { VideoGame } from '../types/videogame.type';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';

@Component({
  selector: 'nwt-add-dialog',
  templateUrl: './dialog.component.html'
})
export class DialogComponent {

  /**
   * Constructeur du dialogue MatDialogRef d'Angular (Material Design)
   */
  constructor(private _dialogRef: MatDialogRef<DialogComponent, VideoGame>, @Optional() @Inject(MAT_DIALOG_DATA) private _videoGame: VideoGame) {
  }

  /**
   * Retourner le jeu vidéo associé au dialogue
   */
  get videoGame(): VideoGame {
    return this._videoGame;
  }


  /**
   * Fermer le dialogue
   */
  onCancel(): void {
    this._dialogRef.close();
  }

  /**
   * Fermer le dialogue et passer un jeu vidéo (modèle) pour traitement sur retour d'un observeur.
   * Le composant utilisant DialogComponent va recevoir cet objet par le biais d'un observeur (s'il est inscrit auprès du sujet).
   */
  onSave(vg: VideoGame): void {
    this._dialogRef.close(vg);
  }
}
