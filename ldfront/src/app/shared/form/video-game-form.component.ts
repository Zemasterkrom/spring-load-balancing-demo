import { Component, EventEmitter, Input, OnChanges, Output } from '@angular/core';
import { VideoGame } from '../types/videogame.type';
import { FormControl, FormGroup, Validators } from '@angular/forms';

@Component({
  selector: 'video-game-form',
  templateUrl: './video-game-form.component.html',
  styleUrls: ['./video-game-form.component.css']
})
export class VideoGameFormComponent implements OnChanges {
  // Propriété permettant de savoir si l'on est en mise à jour ou pas
  private _isUpdateMode: boolean;

  // Modèle du formulaire (jeu vidéo)
  private _model: VideoGame;

  // Emetteur du modèle pour traiter l'annulation du formulaire dans un composant parent
  private readonly _cancel$: EventEmitter<void>;

  // Emetteur du modèle pour traiter l'ajout/modification dans un composant parent
  private readonly _submit$: EventEmitter<VideoGame>;

  // Données du formulaire
  private readonly _form: FormGroup;

  /**
   * Constructeur du formulaire de jeu vidéo
   */
  constructor() {
    this._model = {} as VideoGame;
    this._isUpdateMode = false;
    this._submit$ = new EventEmitter<VideoGame>();
    this._cancel$ = new EventEmitter<void>();
    this._form = VideoGameFormComponent._buildForm();
  }

  @Input()
  set model(model: VideoGame) {
    this._model = model;
  }

  /**
   * Modèle actuel du formulaire (jeu vidéo)
   */
  get model(): VideoGame {
    return this._model;
  }

  /**
   * Retourner les données du formulaire
   */
  get form(): FormGroup {
    return this._form;
  }

  /**
   * Permet de savoir si l'on est en mode mise à jour ou insertion pour le formulaire
   */
  get isUpdateMode(): boolean {
    return this._isUpdateMode;
  }

  @Output('cancel')
  get cancel$(): EventEmitter<void> {
    return this._cancel$;
  }


  @Output('submit')
  get submit$(): EventEmitter<VideoGame> {
    return this._submit$;
  }

  /**
   * Mise à jour du formulaire en cas de récupération des données (mise à jour)
   */
  ngOnChanges(record: any): void {
    if (record.model && Object.keys(record.model.currentValue).length) {
      // Mise à jour des données récupérées
      this._model = record.model.currentValue;
      this._isUpdateMode = !!record.model.currentValue.updateMode;
    } else {
      this._model = {
        id: 0,
        name: '',
        editor: '',
        releasedDate: ''
      };
      this._isUpdateMode = false;
    }

    this._form.patchValue(this._model);
  }

  /**
   * Fermer le formulaire
   */
  cancel(): void {
    this._cancel$.emit();
  }

  /**
   * Emettre les données du jeu vidéo au parent pour traiter les données (ajout/modification)
   */
  submit(vg: VideoGame): void {
    this._submit$.emit(vg);
  }

  /**
   * Construire le formulaire avec un principe de validation
   */
  private static _buildForm(): FormGroup {
    return new FormGroup({
      name: new FormControl('', Validators.compose([
          Validators.required, Validators.pattern(/.*\S.*/)
      ])),
      editor: new FormControl('', Validators.compose([
        Validators.required, Validators.pattern(/.*\S.*/)
      ])),
      description: new FormControl(),
      releasedDate: new FormControl('', Validators.compose([
        Validators.required, Validators.pattern("^[0-9]{2}/[0-9]{2}/[0-9]{4}$")
      ]))
    });
  }
}
