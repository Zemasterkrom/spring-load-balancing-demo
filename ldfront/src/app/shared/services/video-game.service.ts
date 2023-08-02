import {Injectable} from '@angular/core';
import {HttpClient, HttpHeaders} from '@angular/common/http';
import {endpoints} from '../../../environments/final';
import {Observable} from 'rxjs';
import {VideoGame} from '../types/videogame.type';
import {defaultIfEmpty, filter, map} from 'rxjs/operators';

@Injectable({
    providedIn: 'root'
})
export class VideoGameService {
    // Stocker les final de l'API dans le service VideoGameService
    private readonly _apiURL: any;

    constructor(private _http: HttpClient) {
        this._apiURL = {};
        Object.keys(endpoints).forEach((k: string) => this._apiURL[k] = `${(window as any)['environment']['url']}${endpoints[k]}`);
    }

    /**
     * Retourner tous les jeux vidéo existants
     */
    fetchAll(): Observable<VideoGame[]> {
        return this._http.get<VideoGame[]>(this._apiURL.allVideoGames)
            .pipe(
                filter((vg: VideoGame[]) => !!vg),
                defaultIfEmpty([])
            );
    }

    /**
     * Retourner un jeu vidéo spécifique
     * @param id Identifiant du jeu vidéo
     */
    fetchOne(id: string): Observable<VideoGame> {
        return this._http.get<VideoGame>(this._apiURL.oneVideoGame.replace(':id', id));
    }

    /**
     * Ajouter un nouveau jeu vidéo
     * @param vg Jeu vidéo (données)
     */
    create(vg: VideoGame): Observable<any> {
        return this._http.post<VideoGame>(this._apiURL.addVideoGame, vg, VideoGameService._options());
    }

    /**
     * Mettre à jour un jeu vidéo
     * @param id Identifiant du jeu vidéo
     * @param vg Données du jeu vidéo
     */
    update(id: string, vg: VideoGame | undefined): Observable<any> {
        return this._http.put<VideoGame>(this._apiURL.updateVideoGame.replace(':id', id), vg, VideoGameService._options());
    }

    /**
     * Supprimer un jeu vidéo
     * @param id Identifiant du jeu vidéo
     */
    delete(id: string): Observable<string> {
        return this._http.delete(this._apiURL.deleteVideoGame.replace(':id', id))
            .pipe(
                map(() => id)
            );
    }

  /**
   * Modifier la réponse pour inclure une erreur
   * @param vg Objet du jeu vidéo
   * @param code Code d'erreur
   */
    modifyResponseForError(vg: VideoGame | undefined, code: number): VideoGame {
        if (!vg) vg = {} as VideoGame;

        switch (code) {
            case 409:
                vg.error = "Un jeu vidéo avec ce nom est déjà existant";
                break;
            case 400:
                vg.error = "Vous avez utilisé une syntaxe incorrecte";
                break;
            default:
                vg.error = "Une erreur interne inconnue est survenue";
                break;
        }

        return vg;
    }


    /**
     * Function to return request options
     */
    private static _options(headerList: object = {}): any {
        return {headers: new HttpHeaders(Object.assign({'Content-Type': 'application/json'}, headerList))};
    }
}
